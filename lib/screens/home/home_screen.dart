import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/note.dart';
import '../../providers/notes_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/note_card.dart';
import '../../widgets/wordmark.dart';
import '../editor/note_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _searching = false;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---- navigation / actions --------------------------------------------

  Future<void> _create(NoteType type) async {
    final note = await context.read<NotesProvider>().createNote(type: type);
    if (!mounted) return;
    _openEditor(note);
  }

  void _openEditor(Note note) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => NoteEditorScreen(note: note),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    ));
  }

  void _snack(String message, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Undo', onPressed: undo),
      ));
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('New note'),
              onTap: () {
                Navigator.pop(ctx);
                _create(NoteType.note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rtl),
              title: const Text('Checklist'),
              onTap: () {
                Navigator.pop(ctx);
                _create(NoteType.checklist);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showNoteMenu(Note note) {
    final provider = context.read<NotesProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(IconData i, String t, VoidCallback f) => ListTile(
              leading: Icon(i),
              title: Text(t),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: note.deleted
                ? [
                    tile(Icons.restore_from_trash, 'Restore', () {
                      note.deleted = false;
                      provider.updateNote(note);
                    }),
                    tile(Icons.delete_forever_outlined, 'Delete permanently', () => _confirmDeleteForever(note)),
                  ]
                : [
                    tile(note.pinned ? Icons.push_pin_outlined : Icons.push_pin, note.pinned ? 'Unpin' : 'Pin', () {
                      note.pinned = !note.pinned;
                      provider.updateNote(note);
                    }),
                    tile(note.favorite ? Icons.star_border : Icons.star,
                        note.favorite ? 'Remove from favorites' : 'Add to favorites', () {
                      note.favorite = !note.favorite;
                      provider.updateNote(note);
                    }),
                    tile(note.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                        note.archived ? 'Unarchive' : 'Archive', () {
                      final was = note.archived;
                      note.archived = !was;
                      provider.updateNote(note);
                      _snack(was ? 'Note unarchived' : 'Note archived', () {
                        note.archived = was;
                        provider.updateNote(note);
                      });
                    }),
                    tile(Icons.delete_outline, 'Move to Trash', () {
                      note.deleted = true;
                      provider.updateNote(note);
                      _snack('Note moved to Trash', () {
                        note.deleted = false;
                        provider.updateNote(note);
                      });
                    }),
                  ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteForever(Note note) async {
    final provider = context.read<NotesProvider>();
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
    if (ok == true) provider.permanentlyDelete(note);
  }

  Future<void> _confirmEmptyTrash() async {
    final provider = context.read<NotesProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text('All notes in Trash will be permanently deleted. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Empty Trash')),
        ],
      ),
    );
    if (ok == true) provider.emptyTrash();
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _SettingsSheet(),
    );
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<NotesProvider>();
    final notes = provider.visible();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New'),
        backgroundColor: scheme.onSurface,
        foregroundColor: scheme.surface,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NotedWordmark(size: 38),
                        const SizedBox(height: 4),
                        Text("What's on your mind?", style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _searching ? 'Close search' : 'Search',
                    icon: Icon(_searching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() => _searching = !_searching);
                      if (!_searching) {
                        _search.clear();
                        provider.setQuery('');
                      }
                    },
                  ),
                  IconButton(
                    tooltip: provider.gridView ? 'List view' : 'Grid view',
                    icon: Icon(provider.gridView ? Icons.view_agenda_outlined : Icons.grid_view),
                    onPressed: provider.toggleView,
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _showSettings,
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _searching
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: TextField(
                        controller: _search,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search notes, content, tags',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: scheme.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: scheme.outline),
                          ),
                        ),
                        onChanged: provider.setQuery,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final f in const [
                    (NoteFilter.all, 'All'),
                    (NoteFilter.pinned, 'Pinned'),
                    (NoteFilter.favorite, 'Favorites'),
                    (NoteFilter.checklist, 'Checklists'),
                    (NoteFilter.archived, 'Archive'),
                    (NoteFilter.trash, 'Trash'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: provider.filter == f.$1,
                        showCheckmark: false,
                        selectedColor: scheme.onSurface,
                        backgroundColor: scheme.surface,
                        side: BorderSide(color: scheme.outline),
                        labelStyle: TextStyle(
                          color: provider.filter == f.$1 ? scheme.surface : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        onSelected: (_) => provider.setFilter(f.$1),
                      ),
                    ),
                ],
              ),
            ),
            if (provider.filter == NoteFilter.trash && notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Notes in Trash are deleted after ${NotesProvider.trashDays} days.',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                    ),
                    TextButton(onPressed: _confirmEmptyTrash, child: const Text('Empty Trash')),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: notes.isEmpty ? _empty(provider) : _list(provider, notes)),
          ],
        ),
      ),
    );
  }

  Widget _list(NotesProvider provider, List<Note> notes) {
    final double scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0).toDouble();
    if (!provider.gridView) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: notes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => SizedBox(
          height: 118 * scale,
          child: NoteCard(
            note: notes[i],
            compact: true,
            onTap: () => _openEditor(notes[i]),
            onLongPress: () => _showNoteMenu(notes[i]),
          ),
        ),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 900 ? 4 : width >= 600 ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 172 * scale,
      ),
      itemCount: notes.length,
      itemBuilder: (_, i) => NoteCard(
        note: notes[i],
        onTap: () => _openEditor(notes[i]),
        onLongPress: () => _showNoteMenu(notes[i]),
      ),
    );
  }

  Widget _empty(NotesProvider provider) {
    if (provider.query.trim().isNotEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        message: 'Nothing matches your search. Try a different word or tag.',
      );
    }
    switch (provider.filter) {
      case NoteFilter.archived:
        return const EmptyState(
            icon: Icons.archive_outlined, title: 'Archive is empty', message: 'Notes you archive will rest here.');
      case NoteFilter.trash:
        return const EmptyState(
            icon: Icons.delete_outline, title: 'Trash is empty', message: 'Deleted notes wait here before they\'re gone.');
      case NoteFilter.favorite:
        return const EmptyState(
            icon: Icons.star_border, title: 'No favorites yet', message: 'Star a note to keep it close.');
      case NoteFilter.pinned:
        return const EmptyState(
            icon: Icons.push_pin_outlined, title: 'Nothing pinned', message: 'Pin important notes to keep them on top.');
      case NoteFilter.checklist:
        return const EmptyState(
            icon: Icons.checklist_rtl, title: 'No checklists yet', message: 'Turn a plan into a list you can tick off.');
      case NoteFilter.all:
        return EmptyState(
          icon: Icons.edit_note,
          title: 'Nothing here yet.',
          message: 'Capture an idea before it disappears.',
          actionLabel: 'Create your first note',
          onAction: () => _create(NoteType.note),
        );
    }
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeProvider>();
    final notes = context.watch<NotesProvider>();
    final label = TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface);
    final sub = TextStyle(color: scheme.onSurfaceVariant, height: 1.4, fontSize: 13.5);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: AppTheme.display(26, color: scheme.onSurface)),
            const SizedBox(height: 20),
            Text('Appearance', style: label),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ],
                selected: {theme.mode},
                onSelectionChanged: (s) => theme.setMode(s.first),
              ),
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Match app icon to theme'),
                subtitle: Text(
                  'Swaps the launcher icon between light and dark. It updates when Noted. runs, '
                  'and some launchers briefly refresh the icon (or need it re-pinned) when it changes.',
                  style: sub,
                ),
                value: theme.iconFollowsTheme,
                onChanged: theme.setIconFollowsTheme,
              ),
            const SizedBox(height: 20),
            Text('Sort notes by', style: label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in const [
                  ('updated', 'Recently updated'),
                  ('created', 'Recently created'),
                  ('az', 'Title A–Z'),
                ])
                  ChoiceChip(
                    label: Text(s.$2),
                    selected: notes.sort == s.$1,
                    onSelected: (_) => notes.setSort(s.$1),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Storage', style: label),
            const SizedBox(height: 4),
            Text('${notes.all.length} notes on this device', style: sub),
            const SizedBox(height: 20),
            Text('Privacy', style: label),
            const SizedBox(height: 4),
            Text(
              'Your notes are stored only on this device. Nothing is uploaded or shared, and Noted. has no '
              'account, tracking, or network access. It currently asks for no device permissions.',
              style: sub,
            ),
          ],
        ),
      ),
    );
  }
}
