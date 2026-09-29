import 'package:uuid/uuid.dart';

/// The kind of content a note holds. Kept as a plain enum (not a Hive
/// TypeAdapter) so the whole model can be stored as a Map and needs no
/// generated code / build_runner step.
enum NoteType { note, checklist, drawing }

class ChecklistItem {
  final String id;
  String text;
  bool done;

  ChecklistItem({String? id, this.text = '', this.done = false})
      : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'done': done};

  factory ChecklistItem.fromMap(Map map) => ChecklistItem(
        id: map['id'] as String?,
        text: (map['text'] ?? '') as String,
        done: (map['done'] ?? false) as bool,
      );
}

class Note {
  final String id;
  String title;
  String content;
  NoteType type;
  List<ChecklistItem> checklist;
  List<String> tags;
  String color; // 'default' or a hex string like '#F6D9C7'
  bool pinned;
  bool favorite;
  bool archived;
  bool deleted;
  final int createdAt;
  int updatedAt;
  String? drawingData; // base64 PNG snapshot, only used when type == drawing

  Note({
    String? id,
    this.title = '',
    this.content = '',
    this.type = NoteType.note,
    List<ChecklistItem>? checklist,
    List<String>? tags,
    this.color = 'default',
    this.pinned = false,
    this.favorite = false,
    this.archived = false,
    this.deleted = false,
    this.drawingData,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        checklist = checklist ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  int get checklistDone => checklist.where((c) => c.done).length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.name,
        'checklist': checklist.map((c) => c.toMap()).toList(),
        'tags': tags,
        'color': color,
        'pinned': pinned,
        'favorite': favorite,
        'archived': archived,
        'deleted': deleted,
        'drawingData': drawingData,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Note.fromMap(Map map) => Note(
        id: map['id'] as String?,
        title: (map['title'] ?? '') as String,
        content: (map['content'] ?? '') as String,
        type: NoteType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => NoteType.note,
        ),
        checklist: ((map['checklist'] as List?) ?? [])
            .map((c) => ChecklistItem.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList(),
        tags: List<String>.from((map['tags'] as List?) ?? const []),
        color: (map['color'] ?? 'default') as String,
        pinned: (map['pinned'] ?? false) as bool,
        favorite: (map['favorite'] ?? false) as bool,
        archived: (map['archived'] ?? false) as bool,
        deleted: (map['deleted'] ?? false) as bool,
        drawingData: map['drawingData'] as String?,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
      );
}
