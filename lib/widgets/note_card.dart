import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_format.dart';
import '../core/utils/note_colors.dart';
import '../data/models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool compact;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = parseNoteColor(note.color);
    final fg = tone != null ? kInkOnPastel : scheme.onSurface;
    final sub = tone != null ? kInkOnPastel.withOpacity(0.6) : scheme.onSurfaceVariant;
    final total = note.checklist.length;
    final done = note.checklistDone;
    final isChecklist = note.type == NoteType.checklist && total > 0;

    return Semantics(
      button: true,
      label: '${note.title.isEmpty ? 'Untitled' : note.title}. Double tap to open.',
      child: Material(
        color: tone ?? scheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.display(17, color: fg),
                      ),
                    ),
                    if (note.pinned) Icon(Icons.push_pin, size: 14, color: sub),
                    if (note.favorite) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.star, size: 14, color: sub),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: isChecklist
                      ? _ChecklistPreview(note: note, fg: fg, sub: sub)
                      : Text(
                          note.content.trim().isEmpty ? 'No content' : note.content.trim(),
                          maxLines: compact ? 2 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, height: 1.35, color: sub),
                        ),
                ),
                if (isChecklist) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 4,
                      backgroundColor: fg.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Text(
                      isChecklist ? '$done/$total completed' : formatNoteDate(note.updatedAt),
                      style: TextStyle(fontSize: 11.5, color: sub),
                    ),
                    const Spacer(),
                    if (note.tags.isNotEmpty)
                      Flexible(
                        child: Text(
                          '#${note.tags.first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: sub),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistPreview extends StatelessWidget {
  final Note note;
  final Color fg, sub;
  const _ChecklistPreview({required this.note, required this.fg, required this.sub});

  @override
  Widget build(BuildContext context) {
    final items = note.checklist.where((c) => c.text.trim().isNotEmpty).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${c.done ? '☑' : '☐'} ${c.text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: c.done ? sub : fg,
                decoration: c.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
      ],
    );
  }
}
