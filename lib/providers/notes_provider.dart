import 'package:flutter/material.dart';
import '../data/database/note_repository.dart';
import '../data/models/note.dart';

enum NoteFilter { all, pinned, favorite, checklist, archived, trash }

class NotesProvider extends ChangeNotifier {
  final NoteRepository repository;
  List<Note> _notes = [];

  NoteFilter filter = NoteFilter.all;
  String query = '';
  String sort = 'updated'; // 'updated' | 'created' | 'az'
  bool gridView = true;

  /// Notes stay in Trash this many days before being removed for good.
  /// (A note's `updatedAt` is bumped when it's trashed, so it doubles as the
  /// time it entered Trash.)
  static const int trashDays = 30;

  NotesProvider(this.repository) {
    _notes = repository.getAll();
    _purgeExpiredTrash();
  }

  void _purgeExpiredTrash() {
    final cutoff = DateTime.now().subtract(const Duration(days: trashDays)).millisecondsSinceEpoch;
    final expired = _notes.where((n) => n.deleted && n.updatedAt < cutoff).toList();
    for (final n in expired) {
      _notes.remove(n);
      repository.delete(n.id);
    }
  }

  Future<void> emptyTrash() async {
    final trashed = _notes.where((n) => n.deleted).toList();
    for (final n in trashed) {
      _notes.remove(n);
      await repository.delete(n.id);
    }
    notifyListeners();
  }

  List<Note> get all => _notes;

  /// Applies the current filter, search query and sort order.
  List<Note> visible() {
    List<Note> list;
    if (filter == NoteFilter.trash) {
      list = _notes.where((n) => n.deleted).toList();
    } else if (filter == NoteFilter.archived) {
      list = _notes.where((n) => n.archived && !n.deleted).toList();
    } else {
      list = _notes.where((n) => !n.deleted && !n.archived).toList();
      if (filter == NoteFilter.pinned) list = list.where((n) => n.pinned).toList();
      if (filter == NoteFilter.favorite) list = list.where((n) => n.favorite).toList();
      if (filter == NoteFilter.checklist) {
        list = list.where((n) => n.type == NoteType.checklist).toList();
      }
    }

    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where((n) => (n.title + n.content + n.tags.join(' ')).toLowerCase().contains(q))
          .toList();
    }

    // One comparator (pinned first, then the chosen order): Dart's List.sort
    // isn't guaranteed stable, so two successive sorts could reorder ties.
    list.sort((a, b) {
      if (filter != NoteFilter.trash && a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      switch (sort) {
        case 'created':
          return b.createdAt.compareTo(a.createdAt);
        case 'az':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        default:
          return b.updatedAt.compareTo(a.updatedAt);
      }
    });
    return list;
  }

  Future<Note> createNote({NoteType type = NoteType.note}) async {
    final note = Note(
      type: type,
      checklist: type == NoteType.checklist ? [ChecklistItem()] : [],
    );
    _notes.insert(0, note);
    await repository.save(note);
    notifyListeners();
    return note;
  }

  Future<void> updateNote(Note note) async {
    note.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await repository.save(note);
    notifyListeners();
  }

  Future<void> permanentlyDelete(Note note) async {
    _notes.removeWhere((n) => n.id == note.id);
    await repository.delete(note.id);
    notifyListeners();
  }

  void setFilter(NoteFilter f) {
    filter = f;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void setSort(String s) {
    sort = s;
    notifyListeners();
  }

  void toggleView() {
    gridView = !gridView;
    notifyListeners();
  }
}
