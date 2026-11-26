class DiaryCategory {
  final int id;
  final String name;
  final int position;

  const DiaryCategory(this.id, this.name, this.position);

  factory DiaryCategory.fromJson(Map<String, Object?> row) => DiaryCategory(
        row['id'] as int,
        row['name'] as String,
        row['position'] as int,
      );
}
