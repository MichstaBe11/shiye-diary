import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:daily_you/shiye_main.dart' as app;
import 'package:daily_you/entries_database.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/shiye/app.dart';
import 'package:daily_you/shiye/backup.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android 日记、分类、搜索、草稿和照片备份完整流程', (tester) async {
    await app.main();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await tester.pumpAndSettle();
    final db = EntriesDatabase.instance;
    // This suite runs only on the dedicated, newly created test emulator.
    expect(await db.getAllEntries(), isEmpty);
    await tester.tap(find.text('写一页'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byType(DropdownButtonFormField<int>));
    await tester.enterText(
        find.byKey(const ValueKey('diaryTitle')), '阅读，是另一种旅行');
    await tester.enterText(find.byKey(const ValueKey('diaryBody')),
        '今天读到一句话：把注意力放回生活。\n记录阅读摘要，也记录自己的感悟。');
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('diaryTitle')))
            .controller!
            .text,
        '阅读，是另一种旅行');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阅读摘要').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('最近的日记'));
    await waitFor(tester, find.text('阅读，是另一种旅行'));
    expect(find.text('阅读，是另一种旅行'), findsOneWidget);
    final search = find.byType(TextField);
    await tester.enterText(search, '注意力');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('阅读，是另一种旅行'), findsOneWidget);
    await tester.enterText(search, '不存在的词');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await waitFor(tester, find.text('没有找到相关日记'));
    expect(find.text('没有找到相关日记'), findsOneWidget);
    await tester.enterText(search, '');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('分类').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '旅行见闻');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect((await db.getCategories()).any((c) => c.name == '旅行见闻'), isTrue);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('categories');
    await tester.tap(find.text('日记').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('写一页'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byType(DropdownButtonFormField<int>));
    await tester.enterText(find.byType(TextField).at(0), '还没写完的灵感');
    await tester.enterText(find.byType(TextField).at(1), '一个属于自己的日记空间。');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('返回并保存'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('草稿'));
    expect(find.text('草稿'), findsOneWidget);
    final path = await db.getInternalDbPath();
    await db.close();
    await db.initDB(pathOverride: path);
    expect((await db.getAllEntries()).where((e) => e.isDraft).single.title,
        '还没写完的灵感');
    await tester.tap(find.text('还没写完的灵感'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byType(DropdownButtonFormField<int>));
    expect(find.text('已恢复草稿'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('最近的日记'));
    final first = (await db.getAllEntries()).last;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xffe5e7d8), BlendMode.src);
    canvas.drawCircle(
        const Offset(240, 70), 36, Paint()..color = const Color(0xffd2ab70));
    canvas.drawPath(
        Path()
          ..moveTo(0, 240)
          ..lineTo(130, 95)
          ..lineTo(250, 240)
          ..close(),
        Paint()..color = const Color(0xff6d8b74));
    canvas.drawPath(
        Path()
          ..moveTo(160, 240)
          ..lineTo(280, 130)
          ..lineTo(360, 240)
          ..close(),
        Paint()..color = const Color(0xff365b48));
    final image = await recorder.endRecording().toImage(360, 240);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    final name = await db.createImg('fixture.png', bytes);
    await db.addImg(
        EntryImage(
            entryId: first.id,
            imgPath: name!,
            imgRank: 0,
            timeCreate: DateTime.now()),
        updateStatsAndSync: false);
    final backup = await DiaryBackup.export();
    expect(DiaryBackup.parse(backup).images.length, 1);
    await db.deleteDiary(first.id!);
    for (final other in await db.getAllEntries()) {
      await db.deleteDiary(other.id!);
    }
    expect(await DiaryBackup.restore(backup), 2);
    final restored =
        (await db.getAllEntries()).firstWhere((e) => e.title == '阅读，是另一种旅行');
    final photos = await db.getImagesForEntry(restored.id!);
    expect(photos, hasLength(1));
    db.imageCache.clear();
    expect(await db.getImgBytes(photos.single.imgPath), bytes);
    await db.saveDiary(Entry(
        title: '沿途的风景',
        text: '慢慢走，留意身边的小事。\n生活里有很多值得收藏的瞬间。',
        categoryId:
            (await db.getCategories()).firstWhere((c) => c.name == '感悟随笔').id,
        timeCreate: DateTime.now().subtract(const Duration(days: 1)),
        timeModified: DateTime.now()));
    await tester.pumpWidget(const ShiyeApp(key: ValueKey('reload')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('阅读，是另一种旅行'));
    await binding.takeScreenshot('home');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('沿途的风景'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阅读，是另一种旅行'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byType(SelectableText));
    await binding.takeScreenshot('detail');
    await tester.tap(find.byTooltip('编辑日记'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byType(DropdownButtonFormField<int>));
    await binding.takeScreenshot('editor');
    expect(tester.takeException(), isNull);
  });
}
