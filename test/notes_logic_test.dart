import 'package:flutter_test/flutter_test.dart';
import 'package:noted/data/database/note_repository.dart';
import 'package:noted/data/models/note.dart';
import 'package:noted/providers/notes_provider.dart';

/// In-memory stand-in so provider logic can be tested without Hive.
class FakeRepository extends NoteRepository {
  final Map<String, Note> store = {};
  @override
  Future<void> init() async {}
  @override
  List<Note> getAll() => store.values.toList();
  @override
  Future<void> save(Note note) async => store[note.id] = note;
  @override
  Future<void> delete(String id) async => store.remove(id);
}

void main() {
  group('Note model', () {
    test('round-trips through a plain map', () {
      final n = Note(
        title: 'Weekend',
        content: 'hello',
        type: NoteType.checklist,
        checklist: [ChecklistItem(text: 'milk', done: true), ChecklistItem(text: 'eggs')],
        tags: ['home'],
        color: '#F6D9C7',
        pinned: true,
      );
      final back = Note.fromMap(n.toMap());
      expect(back.id, n.id);
      expect(back.title, 'Weekend');
      expect(back.type, NoteType.checklist);
      expect(back.checklist.length, 2);
      expect(back.checklistDone, 1);
      expect(back.tags, ['home']);
      expect(back.color, '#F6D9C7');
      expect(back.pinned, isTrue);
    });

    test('tolerates missing fields', () {
      final n = Note.fromMap({'id': 'x'});
      expect(n.title, '');
      expect(n.type, NoteType.note);
      expect(n.deleted, isFalse);
    });
  });

  group('NotesProvider', () {
    late FakeRepository repo;
    setUp(() => repo = FakeRepository());

    test('hides archived and trashed notes from All; pinned sort first', () {
      final a = Note(title: 'a', updatedAt: 1);
      final b = Note(title: 'b', updatedAt: 2);
      final pinned = Note(title: 'pinned', pinned: true, updatedAt: 0);
      final arch = Note(title: 'arch', archived: true);
      final trash = Note(title: 'trash', deleted: true);
      for (final n in [a, b, pinned, arch, trash]) {
        repo.store[n.id] = n;
      }
      final p = NotesProvider(repo);
      final titles = p.visible().map((n) => n.title).toList();
      expect(titles, ['pinned', 'b', 'a']);
    });

    test('filters and search (title, content, tags)', () {
      final n1 = Note(title: 'Groceries', tags: ['home']);
      final n2 = Note(title: 'Ideas', content: 'build an app', favorite: true);
      repo.store[n1.id] = n1;
      repo.store[n2.id] = n2;
      final p = NotesProvider(repo);

      p.setFilter(NoteFilter.favorite);
      expect(p.visible().single.title, 'Ideas');

      p.setFilter(NoteFilter.all);
      p.setQuery('home');
      expect(p.visible().single.title, 'Groceries');
      p.setQuery('BUILD');
      expect(p.visible().single.title, 'Ideas');
    });

    test('expired trash is purged on start, recent trash is kept', () {
      final old = Note(
        title: 'old',
        deleted: true,
        updatedAt: DateTime.now().subtract(const Duration(days: 45)).millisecondsSinceEpoch,
      );
      final fresh = Note(title: 'fresh', deleted: true);
      repo.store[old.id] = old;
      repo.store[fresh.id] = fresh;
      final p = NotesProvider(repo);
      p.setFilter(NoteFilter.trash);
      expect(p.visible().map((n) => n.title), ['fresh']);
      expect(repo.store.containsKey(old.id), isFalse);
    });

    test('emptyTrash removes only trashed notes', () async {
      final keep = Note(title: 'keep');
      final gone = Note(title: 'gone', deleted: true);
      repo.store[keep.id] = keep;
      repo.store[gone.id] = gone;
      final p = NotesProvider(repo);
      await p.emptyTrash();
      expect(repo.store.values.map((n) => n.title), ['keep']);
    });

    test('createNote(checklist) starts with one empty item', () async {
      final p = NotesProvider(repo);
      final n = await p.createNote(type: NoteType.checklist);
      expect(n.checklist.length, 1);
      expect(repo.store.containsKey(n.id), isTrue);
    });
  });
}
