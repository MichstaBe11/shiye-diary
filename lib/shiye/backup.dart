import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../entries_database.dart';
import '../models/entry.dart';
import '../models/image.dart';

class DiaryBackup {
  // shortcut: backups use memory; switch to streaming for archives above 100 MB.
  static const maxBytes = 100 * 1024 * 1024;

  static Future<Uint8List> export() async {
    final db = EntriesDatabase.instance;
    final categories = await db.getCategories();
    final entries = await db.getAllEntries();
    final images = await db.getAllEntryImages();
    final archive = Archive();
    final manifest = utf8.encode(jsonEncode({
      'format': 'shiye-diary',
      'version': 1,
      'categories': categories
          .map((c) => {'id': c.id, 'name': c.name, 'position': c.position})
          .toList(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'images': images.map((e) => e.toJson()).toList(),
    }));
    var size = manifest.length;
    if (size > maxBytes) throw const FormatException('初版备份上限为 100 MB');
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    for (final image in images) {
      final bytes = await db.getImgBytes(image.imgPath);
      if (bytes == null) throw const FormatException('有照片无法读取，备份已停止；请先检查照片');
      size += bytes.length;
      if (size > maxBytes) {
        throw const FormatException('初版备份上限为 100 MB，请减少照片后重试');
      }
      archive
          .addFile(ArchiveFile('images/${image.imgPath}', bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static ({
    List<Map<String, Object?>> categories,
    List<Map<String, Object?>> entries,
    List<Map<String, Object?>> images,
    Map<String, List<int>> files
  }) parse(Uint8List bytes) {
    if (bytes.length > maxBytes) throw const FormatException('备份文件超过 100 MB');
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    var size = 0;
    final files = <String, List<int>>{};
    for (final file in archive.files) {
      size += file.size;
      if (size > maxBytes || files.containsKey(file.name)) {
        throw const FormatException('备份大小超限或包含重复文件');
      }
      if (!file.isFile ||
          !RegExp(r'^(manifest\.json|images/[a-zA-Z0-9_.-]+)$')
              .hasMatch(file.name)) {
        throw const FormatException('备份中包含不安全的文件路径');
      }
      files[file.name] = file.content as List<int>;
    }
    if (!files.containsKey('manifest.json')) {
      throw const FormatException('这不是拾页日记备份');
    }
    final data = jsonDecode(utf8.decode(files['manifest.json']!));
    if (data is! Map ||
        data['format'] != 'shiye-diary' ||
        data['version'] != 1) {
      throw const FormatException('备份格式或版本不支持');
    }
    List<Map<String, Object?>> rows(String key) => (data[key] as List)
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList();
    final categories = rows('categories');
    final entries = rows('entries');
    final images = rows('images');
    final categoryIds = <int>{};
    final names = <String>{};
    for (final c in categories) {
      if (c['id'] is! int ||
          !categoryIds.add(c['id'] as int) ||
          !names
              .add(EntriesDatabase.validateCategoryName(c['name'] as String))) {
        throw const FormatException('备份分类数据无效');
      }
    }
    final entryIds = <int>{};
    for (final row in entries) {
      final entry = Entry.fromJson(row);
      if (entry.id == null ||
          !entryIds.add(entry.id!) ||
          (entry.categoryId != null &&
              !categoryIds.contains(entry.categoryId)) ||
          ![0, 1].contains(row['is_draft'])) {
        throw const FormatException('备份日记数据无效');
      }
      row
        ..clear()
        ..addAll(entry.toJson());
    }
    final imageIds = <int>{};
    final imageNames = <String>{};
    for (final row in images) {
      final image = EntryImage.fromJson(row);
      if (image.id == null ||
          !imageIds.add(image.id!) ||
          !imageNames.add(image.imgPath) ||
          !entryIds.contains(image.entryId) ||
          !files.containsKey('images/${image.imgPath}')) {
        throw const FormatException('备份照片数据不完整');
      }
      row
        ..clear()
        ..addAll(image.toJson());
    }
    for (final c in categories) {
      c.removeWhere((key, _) => !['id', 'name', 'position'].contains(key));
    }
    return (
      categories: categories,
      entries: entries,
      images: images,
      files: files
    );
  }

  static Future<int> restore(Uint8List bytes) async {
    final backup = parse(bytes);
    final db = EntriesDatabase.instance;
    final created = <String>[];
    try {
      for (final image in backup.images) {
        final name = await db.createImg(
            'restore_${DateTime.now().microsecondsSinceEpoch}',
            Uint8List.fromList(backup.files['images/${image['img_path']}']!));
        if (name == null) throw const FormatException('照片写入失败');
        created.add(name);
        image['img_path'] = name;
      }
      final count = await db.mergeDiaryBackup(
          backup.categories, backup.entries, backup.images);
      return count;
    } finally {
      final referenced =
          (await db.getAllEntryImages()).map((e) => e.imgPath).toSet();
      for (final name in created.where((name) => !referenced.contains(name))) {
        try {
          await db.deleteImg(name);
        } catch (_) {/* Never remove referenced photos. */}
      }
    }
  }
}
