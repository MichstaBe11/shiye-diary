import 'package:flutter/material.dart';
import '../entries_database.dart';
import '../models/entry.dart';
import '../models/image.dart';
import '../widgets/local_image_loader.dart';
import 'common.dart';
import 'editor_page.dart';

class DiaryDetail extends StatefulWidget {
  final Entry entry;
  const DiaryDetail({super.key, required this.entry});
  @override
  State<DiaryDetail> createState() => _DiaryDetailState();
}

class _DiaryDetailState extends State<DiaryDetail> {
  late Entry entry;
  String category = '未分类';
  List<EntryImage> images = [];
  bool busy = true;
  @override
  void initState() {
    super.initState();
    entry = widget.entry;
    load();
  }

  Future<void> load() async {
    try {
      final value = await EntriesDatabase.instance.getEntry(entry.id!);
      if (value == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final photos =
          await EntriesDatabase.instance.getImagesForEntry(entry.id!);
      final categories = await EntriesDatabase.instance.getCategories();
      if (mounted) {
        setState(() {
          entry = value;
          images = photos;
          busy = false;
          category = categories
                  .where((e) => e.id == entry.categoryId)
                  .firstOrNull
                  ?.name ??
              '未分类';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showMessage(context, '读取失败，请返回重试');
      }
    }
  }

  Future<void> edit() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => DiaryEditor(entry: entry)));
    await load();
  }

  Future<void> delete() async {
    if (!await confirm(
        context, '删除这篇日记？', '文字和日记中的照片副本将被删除。此操作无法撤销，建议先导出备份。')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await EntriesDatabase.instance.deleteDiary(entry.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showMessage(context, '删除失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('这一页'), actions: [
          IconButton(
              tooltip: '编辑日记',
              onPressed: busy ? null : edit,
              icon: const Icon(Icons.edit_outlined)),
          IconButton(
              tooltip: '删除日记',
              onPressed: busy ? null : delete,
              icon: const Icon(Icons.delete_outline)),
        ]),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 50),
                    children: [
                      Text(diaryDate(entry.timeCreate),
                          style: const TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 18),
                      SelectableText(entry.title.isEmpty ? '无题' : entry.title,
                          style: const TextStyle(
                              fontSize: 28,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              color: ink)),
                      const SizedBox(height: 12),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                              label: Text(category),
                              avatar:
                                  const Icon(Icons.folder_outlined, size: 16))),
                      if (entry.isDraft)
                        const Text('草稿 · 可继续编辑',
                            style: TextStyle(color: muted)),
                      const SizedBox(height: 20),
                      SelectableText(entry.text,
                          style: const TextStyle(fontSize: 17, height: 1.9)),
                      const SizedBox(height: 24),
                      for (var i = 0; i < images.length; i++)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                    onTap: () => openPhotos(context, images, i),
                                    child: LocalImageLoader(
                                        imagePath: images[i].imgPath,
                                        cacheSize: 1000)))),
                    ]),
              )),
      );
}
