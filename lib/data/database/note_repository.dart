import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';

/// Stores each note as a plain Map inside a Hive box. This avoids Hive's
/// generated TypeAdapter step entirely (Map/List/String/num/bool are
/// supported natively), which matters here because there's no way to run
/// `build_runner` in the environment this file was authored in.
class NoteRepository {
  static const _boxName = 'notes';
  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  List<Note> getAll() =>
      _box.values.map((e) => Note.fromMap(Map<String, dynamic>.from(e as Map))).toList();

  Future<void> save(Note note) async {
    await _box.put(note.id, note.toMap());
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
