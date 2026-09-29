import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/note_colors.dart';
import '../../data/models/note.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/drawing_canvas.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note note;
  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const _autosaveDelay = Duration(milliseconds: 500);

  late final NotesProvider _provider;
  late final TextEditingController _title;
  late final TextEditingController _content;
  final TextEditingController _tagInput = TextEditingController();
  Timer? _debounce;
  bool _saving = false;
  bool _dirty = false; // unsaved edits pending
  bool _discard = false; // note was deleted permanently; don't re-save it
  String? _focusItemId; // checklist row that should grab focus (newly added)

  Note get note => widget.note;

  @override
  void initState() {
    super.initState();
    _provider = context.read<NotesProvider>();
    _title = TextEditingController(text: note.title);
    _content = TextEditingController(text: note.content);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _content.dispose();
    _tagInput.dispose();
    // Flush after the frame: notifying listeners while the tree is being
    // torn down is not allowed, so defer to a microtask.
    final provider = _provider;
    final n = note;
    final empty = _isEmpty(n);
    final dirty = _dirty;
    final discard = _discard;
    if (!discard) {
      Future.microtask(() {
        if (empty) {
          provider.permanentlyDelete(n); // never keep blank notes around
        } else if (dirty) {
          provider.updateNote(n); // only touch updatedAt if something changed
        }
      });
    }
    super.dispose();
  }

  bool _isEmpty(Note n) =>
      n.title.trim().isEmpty &&
      n.content.trim().isEmpty &&
      n.tags.isEmpty &&
      (n.drawingData == null || n.drawingData!.isEmpty) &&
      n.checklist.every((c) => c.text.trim().isEmpty);

  void _scheduleSave() {
    _dirty = true;
    setState(() => _saving = true);
    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, () async {
      await _provider.updateNote(note);
      _dirty = false;
      if (mounted) setState(() => _saving = false);
    });
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    await _provider.updateNote(note);
    _dirty = false;
    if (mounted) setState(() => _saving = false);
  }

  // ---- actions ----------------------------------------------------------

  void _togglePin() {
    setState(() => note.pinned = !note.pinned);
    _saveNow();
  }

  void _toggleFavorite() {
    setState(() => note.favorite = !note.favorite);
    _saveNow();
  }

  void _moveTo({required bool archive}) {
    final messenger = ScaffoldMessenger.of(context);
    final provider = _provider;
    final n = note;
    if (archive) {
      n.archived = !n.archived;
    } else {
      n.deleted = true;
    }
    final wasArchive = archive;
    final nowArchived = n.archived;
    provider.updateNote(n);
    _dirty = false;
    _debounce?.cancel();
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(wasArchive
            ? (nowArchived ? 'Note archived' : 'Note unarchived')
            : 'Note moved to Trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (wasArchive) {
              n.archived = !nowArchived;
            } else {
              n.deleted = false;
            }
            provider.updateNote(n);
          },
        ),
      ));
  }

  void _restore() {
    note.deleted = false;
    _provider.updateNote(note);
    _dirty = false;
    _debounce?.cancel();
    Navigator.of(context).pop();
  }

  Future<void> _deleteForever() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text('This note will be gone for good. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final provider = _provider;
      final n = note;
      _discard = true;
      _debounce?.cancel();
      Navigator.of(context).pop();
      provider.permanentlyDelete(n);
    }
  }

  void _addTag(String raw) {
    final t = raw.trim().replaceAll('#', '');
    if (t.isEmpty || note.tags.contains(t)) return;
    setState(() => note.tags.add(t));
    _tagInput.clear();
    _scheduleSave();
  }

  // ---- checklist --------------------------------------------------------

  void _addChecklistItem({int? afterIndex}) {
    final item = ChecklistItem();
    setState(() {
      if (afterIndex == null || afterIndex >= note.checklist.length - 1) {
        note.checklist.add(item);
      } else {
        note.checklist.insert(afterIndex + 1, item);
      }
      _focusItemId = item.id;
    });
    _scheduleSave();
  }

  void _toggleItem(ChecklistItem c) {
    HapticFeedback.selectionClick();
    setState(() => c.done = !c.done);
    _scheduleSave();
  }

  void _removeItem(ChecklistItem c) {
    setState(() => note.checklist.removeWhere((x) => x.id == c.id));
    _scheduleSave();
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = parseNoteColor(note.color);
    final fg = tone != null ? kInkOnPastel : scheme.onSurface;
    final sub = tone != null ? kInkOnPastel.withOpacity(0.6) : scheme.onSurfaceVariant;
    final isChecklist = note.type == NoteType.checklist;
    final isDrawing = note.type == NoteType.drawing;
    final inTrash = note.deleted;

    return Scaffold(
      backgroundColor: tone ?? Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: tone ?? Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: fg,
        actions: inTrash
            ? [
                IconButton(
                    tooltip: 'Restore', icon: const Icon(Icons.restore_from_trash), onPressed: _restore),
                IconButton(
                    tooltip: 'Delete permanently',
                    icon: const Icon(Icons.delete_forever_outlined),
                    onPressed: _deleteForever),
              ]
            : [
                IconButton(
                  tooltip: note.pinned ? 'Unpin' : 'Pin',
                  icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: _togglePin,
                ),
                IconButton(
                  tooltip: note.favorite ? 'Remove from favorites' : 'Add to favorites',
                  icon: Icon(note.favorite ? Icons.star : Icons.star_border),
                  onPressed: _toggleFavorite,
                ),
                IconButton(
                  tooltip: note.archived ? 'Unarchive' : 'Archive',
                  icon: Icon(note.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  onPressed: () => _moveTo(archive: true),
                ),
                IconButton(
                  tooltip: 'Move to Trash',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _moveTo(archive: false),
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  TextField(
                    controller: _title,
                    readOnly: inTrash,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTheme.display(28, color: fg),
                    decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: AppTheme.display(28, color: sub),
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (v) {
                      note.title = v;
                      _scheduleSave();
                    },
                  ),
                  _tagRow(fg, sub),
                  const SizedBox(height: 8),
                  if (isDrawing)
                    _drawing(inTrash)
                  else if (isChecklist)
                    _checklist(fg, sub, scheme, inTrash)
                  else
                    _contentField(fg, sub, inTrash),
                ],
              ),
            ),
            if (!isDrawing) _bottomBar(fg, sub, isChecklist),
          ],
        ),
      ),
    );
  }

  Widget _drawing(bool readOnly) {
    if (readOnly) {
      // Trash is read-only: show the saved sketch as a plain image instead
      // of a live (editable) canvas.
      final data = note.drawingData;
      if (data == null || data.isEmpty) {
        return const Padding(padding: EdgeInsets.only(top: 24), child: Text('Empty sketch'));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(base64Decode(data)),
      );
    }
    return DrawingCanvas(
      initialPng: note.drawingData,
      onChanged: (png) {
        note.drawingData = png;
        _saveNow();
      },
    );
  }

  Widget _contentField(Color fg, Color sub, bool readOnly) {
    return TextField(
      controller: _content,
      readOnly: readOnly,
      maxLines: null,
      minLines: 12,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 16.5, height: 1.5, color: fg),
      decoration: InputDecoration(
        hintText: 'Start writing…',
        hintStyle: TextStyle(color: sub),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: (v) {
        note.content = v;
        _scheduleSave();
      },
    );
  }

  Widget _tagRow(Color fg, Color sub) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final t in note.tags)
          InputChip(
            label: Text('#$t', style: TextStyle(color: fg, fontSize: 12.5)),
            backgroundColor: fg.withOpacity(0.08),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            onDeleted: () {
              setState(() => note.tags.remove(t));
              _scheduleSave();
            },
          ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _tagInput,
            style: TextStyle(fontSize: 13, color: fg),
            decoration: InputDecoration(
              hintText: '+ add tag',
              hintStyle: TextStyle(color: sub, fontSize: 13),
              isDense: true,
              border: InputBorder.none,
              filled: false,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: _addTag,
          ),
        ),
      ],
    );
  }

  Widget _checklist(Color fg, Color sub, ColorScheme scheme, bool readOnly) {
    final total = note.checklist.length;
    final done = note.checklistDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('$done/$total completed', style: TextStyle(color: sub, fontSize: 12.5)),
          ),
        for (var i = 0; i < note.checklist.length; i++)
          _ChecklistRow(
            key: ValueKey(note.checklist[i].id),
            item: note.checklist[i],
            fg: fg,
            sub: sub,
            accent: scheme.primary,
            readOnly: readOnly,
            autofocus: note.checklist[i].id == _focusItemId,
            onToggle: () => _toggleItem(note.checklist[i]),
            onChanged: (v) {
              note.checklist[i].text = v;
              _scheduleSave();
            },
            onSubmit: () => _addChecklistItem(afterIndex: i),
            onRemove: () => _removeItem(note.checklist[i]),
          ),
        if (!readOnly)
          TextButton.icon(
            onPressed: () => _addChecklistItem(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
            style: TextButton.styleFrom(foregroundColor: sub),
          ),
      ],
    );
  }

  Widget _bottomBar(Color fg, Color sub, bool isChecklist) {
    final words = isChecklist ? 0 : RegExp(r'\S+').allMatches(note.content).length;
    final mins = words == 0 ? 0 : (words / 200).ceil().clamp(1, 999);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in kNoteSwatches)
                  _Swatch(
                    value: s,
                    selected: note.color == s,
                    onTap: () {
                      setState(() => note.color = s);
                      _saveNow();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(_saving ? 'Saving…' : 'Saved', style: TextStyle(color: sub, fontSize: 12)),
              const Spacer(),
              if (words > 0)
                Text('$words words · $mins min read', style: TextStyle(color: sub, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = parseNoteColor(value) ?? scheme.surface;
    return Semantics(
      button: true,
      selected: selected,
      label: value == 'default' ? 'Default color' : 'Note color $value',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 16, color: parseNoteColor(value) != null ? kInkOnPastel : scheme.onSurface)
              : (value == 'default' ? Icon(Icons.block, size: 14, color: scheme.onSurfaceVariant) : null),
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatefulWidget {
  final ChecklistItem item;
  final Color fg, sub, accent;
  final bool readOnly, autofocus;
  final VoidCallback onToggle, onSubmit, onRemove;
  final ValueChanged<String> onChanged;

  const _ChecklistRow({
    super.key,
    required this.item,
    required this.fg,
    required this.sub,
    required this.accent,
    required this.readOnly,
    required this.autofocus,
    required this.onToggle,
    required this.onChanged,
    required this.onSubmit,
    required this.onRemove,
  });

  @override
  State<_ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends State<_ChecklistRow> {
  late final TextEditingController _c = TextEditingController(text: widget.item.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.item.done;
    return Row(
      children: [
        Semantics(
          button: true,
          checked: done,
          label: done ? 'Completed. Double tap to mark not done.' : 'Not done. Double tap to complete.',
          child: InkResponse(
            onTap: widget.readOnly ? null : widget.onToggle,
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(10), // ≥ 44dp touch target with the 24dp box
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: done ? widget.accent : Colors.transparent,
                  border: Border.all(color: done ? widget.accent : widget.sub, width: 1.6),
                ),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: done ? 1 : 0,
                  child: const Icon(Icons.check, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: done ? 0.5 : 1,
            child: TextField(
              controller: _c,
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 16.5,
                color: widget.fg,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: widget.sub,
              ),
              decoration: const InputDecoration(
                hintText: 'List item',
                isDense: true,
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: widget.onChanged,
              onSubmitted: (_) => widget.onSubmit(),
            ),
          ),
        ),
        if (!widget.readOnly)
          IconButton(
            tooltip: 'Remove item',
            icon: Icon(Icons.close, size: 18, color: widget.sub),
            onPressed: widget.onRemove,
          ),
      ],
    );
  }
}
