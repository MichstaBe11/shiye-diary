const String entriesTable = 'entries';

const String deprecatedImgPath = 'img_path';

class EntryFields {
  static const List<String> values = [
    id,
    text,
    mood,
    timeCreate,
    timeModified,
    title,
    categoryId,
    isDraft
  ];
  static const String title = 'title';
  static const String categoryId = 'category_id';
  static const String isDraft = 'is_draft';
  static const String id = 'id';
  static const String text = 'text';
  static const String mood = 'mood';
  static const String timeCreate = 'time_create';
  static const String timeModified = 'time_modified';
}

class Entry {
  final int? id;
  final String text;
  final String title;
  final int? categoryId;
  final bool isDraft;
  final int? mood;
  final DateTime timeCreate;
  final DateTime timeModified;

  const Entry({
    this.id,
    required this.text,
    this.title = '',
    this.categoryId,
    this.isDraft = false,
    this.mood,
    required this.timeCreate,
    required this.timeModified,
  });

  static const _unset = Object();

  Entry copy({
    int? id,
    String? text,
    String? title,
    Object? categoryId = _unset,
    bool? isDraft,
    Object? mood = _unset,
    DateTime? timeCreate,
    DateTime? timeModified,
  }) =>
      Entry(
        id: id ?? this.id,
        text: text ?? this.text,
        title: title ?? this.title,
        categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
        isDraft: isDraft ?? this.isDraft,
        mood: mood == _unset ? this.mood : mood as int?,
        timeCreate: timeCreate ?? this.timeCreate,
        timeModified: timeModified ?? this.timeModified,
      );

  static Entry fromJson(Map<String, Object?> json) => Entry(
        id: json[EntryFields.id] as int?,
        text: json[EntryFields.text] as String,
        title: json[EntryFields.title] as String? ?? '',
        categoryId: json[EntryFields.categoryId] as int?,
        isDraft: json[EntryFields.isDraft] == 1,
        mood: json[EntryFields.mood] as int?,
        timeCreate: DateTime.parse(json[EntryFields.timeCreate] as String),
        timeModified: DateTime.parse(json[EntryFields.timeModified] as String),
      );

  Map<String, Object?> toJson() => {
        EntryFields.id: id,
        EntryFields.text: text,
        EntryFields.title: title,
        EntryFields.categoryId: categoryId,
        EntryFields.isDraft: isDraft ? 1 : 0,
        EntryFields.mood: mood,
        EntryFields.timeCreate: timeCreate.toIso8601String(),
        EntryFields.timeModified: timeModified.toIso8601String(),
      };
}
