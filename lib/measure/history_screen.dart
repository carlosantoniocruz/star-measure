import 'package:flutter/material.dart';

import '../common/caption.dart';
import '../theme.dart';
import 'recording.dart';
import 'recording_sheet.dart';
import 'recording_store.dart';
import 'share_recording.dart';
import 'shape_outline.dart';
import 'units.dart';

/// Every saved measurement, newest first. Scroll down to go further back.
/// Long-press a row (or use the menu) to select; share, copy, or delete the
/// selection, or delete everything.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.store, required this.units});

  final RecordingStore store;
  final UnitSystem units;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _selected = <String>{};
  bool _selecting = false;

  void _enterSelecting([String? firstId]) => setState(() {
        _selecting = true;
        if (firstId != null) _selected.add(firstId);
      });

  void _exitSelecting() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _toggle(String id) => setState(() {
        if (!_selected.add(id)) _selected.remove(id);
      });

  Future<bool> _confirm({required String title, required String action}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.darkTyrianBlue,
        title: Text(title, style: const TextStyle(color: Palette.white, fontSize: 18, fontWeight: FontWeight.w400)),
        content: const Text("This can't be undone.", style: TextStyle(color: Palette.warmGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Palette.warmGray),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Palette.white),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static String _count(int n) => n == 1 ? '1 measurement' : '$n measurements';

  Future<void> _deleteSelected() async {
    final ids = {..._selected};
    if (ids.isEmpty) return;
    if (!await _confirm(title: 'Delete ${_count(ids.length)}?', action: 'Delete')) return;
    if (!mounted) return;
    _exitSelecting();
    await widget.store.removeMany(ids);
  }

  Future<void> _deleteAll() async {
    final n = widget.store.items.length;
    if (n == 0) return;
    if (!await _confirm(title: 'Delete all ${_count(n)}?', action: 'Delete all')) return;
    if (!mounted) return;
    _exitSelecting();
    await widget.store.clear();
  }

  /// The selection as one .txt file or one block of copied text, in list
  /// order (newest first).
  void _shareSelected(ShareChoice choice) {
    final picked = widget.store.items.where((r) => _selected.contains(r.id)).toList();
    if (picked.isEmpty) return;
    performBulkShareChoice(context, picked, widget.units, choice);
  }

  Future<void> _open(Recording r) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.darkTyrianBlue,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => RecordingSheet(
        title: 'MEASUREMENT',
        recording: r,
        units: widget.units,
        onChoice: (choice) {
          Navigator.pop(sheetContext);
          performShareChoice(context, r, widget.units, choice);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back leaves selection mode first, like most Android lists.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelecting();
      },
      child: Scaffold(
        backgroundColor: Palette.darkTyrianBlue,
        appBar: _buildAppBar(),
        body: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final items = widget.store.items;
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'No measurements yet.\nPlace two or more dots, then hold anywhere on screen to save.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Palette.warmGray, fontSize: 14, height: 1.5),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: 72, color: Palette.white.withValues(alpha: 0.08)),
              itemBuilder: (context, i) => _row(items[i]),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Palette.darkTyrianBlue,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Palette.white,
      elevation: 0,
      centerTitle: true,
      leading: _selecting
          ? IconButton(
              tooltip: 'Cancel selection',
              icon: const Icon(Icons.close_rounded),
              onPressed: _exitSelecting,
            )
          : IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.maybePop(context),
            ),
      title: _selecting
          ? Text('${_selected.length} selected', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400))
          : const Caption('HISTORY', color: Palette.white),
      actions: [
        ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final items = widget.store.items;
            if (_selecting) {
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Select all',
                    icon: const Icon(Icons.select_all_rounded),
                    onPressed: items.isEmpty
                        ? null
                        : () => setState(() => _selected
                          ..clear()
                          ..addAll(items.map((r) => r.id))),
                  ),
                  ShareMenuButton(enabled: _selected.isNotEmpty, onSelected: _shareSelected),
                  IconButton(
                    tooltip: 'Delete selected',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Palette.peachRed,
                    onPressed: _selected.isEmpty ? null : _deleteSelected,
                  ),
                ],
              );
            }
            return PopupMenuButton<String>(
              tooltip: 'More',
              enabled: items.isNotEmpty,
              color: Palette.darkTyrianBlue,
              onSelected: (v) => v == 'select' ? _enterSelecting() : _deleteAll(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'select', child: Text('Select')),
                PopupMenuItem(value: 'all', child: Text('Delete all')),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _row(Recording r) {
    final picked = _selected.contains(r.id);
    return ListTile(
      key: ValueKey(r.id),
      selected: picked,
      selectedTileColor: Palette.lightMauve.withValues(alpha: 0.12),
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: SizedBox(
        width: 44,
        height: 44,
        child: CustomPaint(
          painter: _ShapeThumb(shapeOutline(r.points), picked ? Palette.lightMauve : Palette.white),
        ),
      ),
      title: Text(
        formatLength(r.total, widget.units),
        style: const TextStyle(color: Palette.white, fontSize: 20, fontWeight: FontWeight.w300),
      ),
      subtitle: Text(
        '${r.points.length} points',
        style: const TextStyle(color: Palette.warmGray, fontSize: 12),
      ),
      trailing: _selecting
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                picked ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: picked ? Palette.lightMauve : Palette.warmGray,
              ),
            )
          : ShareMenuButton(onSelected: (c) => performShareChoice(context, r, widget.units, c)),
      onTap: _selecting ? () => _toggle(r.id) : () => _open(r),
      onLongPress: _selecting ? () => _toggle(r.id) : () => _enterSelecting(r.id),
    );
  }
}

/// The measurement's shape as a tiny constellation.
class _ShapeThumb extends CustomPainter {
  const _ShapeThumb(this.outline, this.color);

  final List<Offset> outline;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (outline.isEmpty) return;
    const pad = 7.0;
    final inner = Size(size.width - pad * 2, size.height - pad * 2);
    final pts = [for (final o in outline) Offset(pad + o.dx * inner.width, pad + o.dy * inner.height)];

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.7);
    canvas.drawPath(Path()..addPolygon(pts, false), line);

    final dot = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, 2.6, dot);
    }
  }

  @override
  bool shouldRepaint(_ShapeThumb old) => old.outline != outline || old.color != color;
}
