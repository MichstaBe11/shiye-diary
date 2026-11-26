import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_you/entries_database.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/shiye/backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = EntriesDatabase.instance;
  late Directory temp;
  Entry note(
          {String title = '阅读摘要',
          String text = '今天读到了关于勇气的一句话',
          int? category,
          bool draft = false}) =>
      Entry(
          title: title,
          text: text,
          categoryId: category,
          isDraft: draft,
          timeCreate: DateTime(2026, 11, 25),
          timeModified: DateTime(2026, 11, 25));

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shiye_test_');
    await db.initDB(pathOverride: '${temp.path}/test.db');
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('预设、自定义分类、排序、重复名称校验', () async {
    expect((await db.getCategories()).map((e) => e.name),
        ['阅读摘要', '人物故事', '感悟随笔', '灵感', '待办']);
    final id = await db.saveCategory('  旅行见闻  ');
    await expectLater(db.saveCategory('旅行见闻'), throwsFormatException);
    await expectLater(db.saveCategory('未分类'), throwsFormatException);
    await db.saveCategory('旅行', id: id);
    final ids =
        (await db.getCategories()).map((e) => e.id).toList().reversed.toList();
    await db.reorderCategories(ids);
    expect((await db.getCategories()).first.name, '旅行');
  });

  test('搜索标题与正文，并正确叠加分类；百分号按字面搜索', () async {
    final id = (await db.getCategories()).first.id;
    await db.saveDiary(note(category: id));
    await db.saveDiary(note(title: '灵感', text: '进度 100% _ 成功'));
    expect((await db.searchEntries('勇气')).length, 1);
    expect((await db.searchEntries('阅读')).length, 1);
    expect(await db.searchEntries('勇气', uncategorized: true), isEmpty);
    expect((await db.searchEntries('勇气', categoryId: id)).length, 1);
    expect((await db.searchEntries('%')).length, 1);
    expect((await db.searchEntries('_')).length, 1);
    expect(await db.searchEntries("' OR 1=1 --"), isEmpty);
  });

  test('重命名和删除分类保留日记；已删分类无法重新挂回日记', () async {
    final id = (await db.getCategories()).first.id;
    final entry = await db.saveDiary(note(category: id));
    await db.saveCategory('读书', id: id);
    expect((await db.getEntry(entry.id!))!.categoryId, id);
    await db.deleteCategory(id);
    expect((await db.getEntry(entry.id!))!.text, entry.text);
    expect((await db.getEntry(entry.id!))!.categoryId, isNull);
    await db.saveDiary(entry);
    expect((await db.getEntry(entry.id!))!.categoryId, isNull);
  });

  test('草稿关闭数据库重开后可恢复，再发布为正式日记', () async {
    final entry = await db.saveDiary(note(draft: true));
    await db.close();
    await db.initDB(pathOverride: '${temp.path}/test.db');
    expect((await db.getEntry(entry.id!))!.isDraft, isTrue);
    await db.saveDiary(entry.copy(isDraft: false, text: '已完成'));
    expect((await db.getEntry(entry.id!))!.text, '已完成');
    expect((await db.getAllEntries()).length, 1);
    await db.deleteDiary(entry.id!);
    expect(await db.getAllEntries(), isEmpty);
  });

  test('v3 数据库升级保留文字、日期与照片关联', () async {
    await db.close();
    final path = '${temp.path}/legacy.db';
    final legacy =
        await openDatabase(path, version: 3, onCreate: (sql, _) async {
      await sql.execute(
          'CREATE TABLE entries (id INTEGER PRIMARY KEY, text TEXT NOT NULL, mood INTEGER, time_create TEXT, time_modified TEXT)');
      await sql.execute(
          'CREATE TABLE entry_images (id INTEGER PRIMARY KEY, entry_id INTEGER, img_path TEXT, img_rank INTEGER, time_create TEXT)');
      await sql.insert('entries', {
        'id': 7,
        'text': '旧日记',
        'time_create': '2025-01-01T00:00:00.000',
        'time_modified': '2025-01-01T00:00:00.000'
      });
      await sql.insert('entry_images', {
        'id': 3,
        'entry_id': 7,
        'img_path': 'old.jpg',
        'img_rank': 0,
        'time_create': '2025-01-01T00:00:00.000'
      });
    });
    await legacy.close();
    await db.initDB(pathOverride: path);
    expect((await db.getEntry(7))!.text, '旧日记');
    expect((await db.getEntry(7))!.title, '');
    expect((await db.getImagesForEntry(7)).single.imgPath, 'old.jpg');
    expect((await db.getCategories()).length, 5);
  });

  test('备份导入以副本添加，保留已有内容和相同文字的不同日记', () async {
    await db.saveDiary(note(title: '本机原有'));
    final imported = note(title: '导入日记').copy(id: 42).toJson();
    expect(await db.mergeDiaryBackup([], [imported], []), 1);
    expect(await db.mergeDiaryBackup([], [imported], []), 1);
    expect((await db.getAllEntries()).length, 3);
  });

  test('损坏备份与路径穿越被拒绝，数据库内容不受影响', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('../unsafe.txt', 3, [1, 2, 3]));
    expect(
        () =>
            DiaryBackup.parse(Uint8List.fromList(ZipEncoder().encode(archive))),
        throwsFormatException);
    final bad = utf8.encode(jsonEncode({'format': 'other', 'version': 1}));
    final other = Archive()
      ..addFile(ArchiveFile('manifest.json', bad.length, bad));
    expect(
        () => DiaryBackup.parse(Uint8List.fromList(ZipEncoder().encode(other))),
        throwsFormatException);
    expect(await db.getAllEntries(), isEmpty);
  });

  test('文字、分类、照片完整导出恢复；副本照片不依赖原文件', () async {
    final category = (await db.getCategories()).first;
    final entry = await db.saveDiary(note(title: '有照片的书摘', category: category.id));
    final photo = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3, 4]);
    final name = await db.createImg('test.png', photo);
    await db.addImg(EntryImage(entryId: entry.id, imgPath: name!, imgRank: 0, timeCreate: DateTime.now()), updateStatsAndSync: false);
    final backup = await DiaryBackup.export();
    await db.deleteDiary(entry.id!);
    await db.deleteCategory(category.id);
    expect(await DiaryBackup.restore(backup), 1);
    final restored = (await db.getAllEntries()).single;
    expect(restored.title, '有照片的书摘');
    final categories = await db.getCategories();
    expect(categories.singleWhere((c) => c.id == restored.categoryId).name, '阅读摘要');
    final image = (await db.getImagesForEntry(restored.id!)).single;
    db.imageCache.clear();
    expect(await db.getImgBytes(image.imgPath), photo);
  });
}
