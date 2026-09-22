import 'package:flutter/material.dart';

import '../common/caption.dart';
import '../common/diamond.dart';
import '../theme.dart';
import 'recording.dart';
import 'recording_sheet.dart';
import 'recording_store.dart';
import 'shape_outline.dart';
import 'units.dart';

/// Every saved measurement, newest first. Scroll down to go further back.
/// Long-press a row (or use the menu) to select; delete the selection or everything.
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
    final palette = Palette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.card,
        title: Text(title, style: TextStyle(color: palette.onSurface, fontSize: 18, fontWeight: FontWeight.w400)),
        content: Text("This can't be undone.", style: TextStyle(color: palette.onSurfaceMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: palette.onSurfaceMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: palette.alertOnCard),
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

  Future<void> _open(Recording r) {
    final palette = Palette.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.card,
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
    final palette = Palette.of(context);
    return PopScope(
      // Back leaves selection mode first, like most Android lists.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelecting();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: _buildAppBar(palette),
        body: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final items = widget.store.items;
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'No measurements yet.\nPlace two or more points, then hold the diamond to save.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.onBaseMuted, fontSize: 14, height: 1.5),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: 72, color: palette.onBase.withValues(alpha: 0.08)),
              itemBuilder: (context, i) => _row(items[i], palette),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Palette palette) {
    return AppBar(
      backgroundColor: palette.bar,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.onSurface,
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
          : Caption('HISTORY', color: palette.onSurface),
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
                  IconButton(
                    tooltip: 'Delete selected',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: palette.alertIcon,
                    onPressed: _selected.isEmpty ? null : _deleteSelected,
                  ),
                ],
              );
            }
            return PopupMenuButton<String>(
              tooltip: 'More',
              enabled: items.isNotEmpty,
              color: palette.card,
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

  Widget _row(Recording r, Palette palette) {
    final picked = _selected.contains(r.id);
    return ListTile(
      key: ValueKey(r.id),
      selected: picked,
      selectedTileColor: palette.emphasis.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: SizedBox(
        width: 44,
        height: 44,
        child: CustomPaint(
          painter: _ShapeThumb(shapeOutline(r.points), picked ? palette.emphasis : palette.onBase),
        ),
      ),
      title: Text(
        formatLength(r.total, widget.units),
        style: TextStyle(color: palette.onBase, fontSize: 20, fontWeight: FontWeight.w300),
      ),
      subtitle: Text(
        '${r.points.length} points · ${formatStamp(r.createdAt)}',
        style: TextStyle(color: palette.onBaseMuted, fontSize: 12),
      ),
      trailing: _selecting
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                picked ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: picked ? palette.emphasis : palette.onBaseMuted,
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
      canvas.drawPath(diamondPath(p, 2.6), dot);
    }
  }

  @override
  bool shouldRepaint(_ShapeThumb old) => old.outline != outline || old.color != color;
}
