import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../entries_database.dart';
import '../models/entry.dart';
import '../models/image.dart';
import '../widgets/local_image_loader.dart';
import 'category.dart';
import 'common.dart';

class DiaryEditor extends StatefulWidget {
  final Entry? entry;
  final int? initialCategory;
  const DiaryEditor({super.key, this.entry, this.initialCategory});
  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> with WidgetsBindingObserver {
  final title = TextEditingController();
  final body = TextEditingController();
  final db = EntriesDatabase.instance;
  Entry? entry;
  List<DiaryCategory> categories = [];
  List<EntryImage> images = [];
  int? categoryId;
  late DateTime date;
  Timer? timer;
  Future<void> tail = Future.value();
  String status = '输入后自动保存草稿';
  bool ready = false;
  bool busy = false;
  bool leaving = false;
  bool dirty = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    entry = widget.entry;
    title.text = entry?.title ?? '';
    body.text = entry?.text ?? '';
    date = entry?.timeCreate ?? DateTime.now();
    categoryId = entry?.categoryId ?? widget.initialCategory;
    title.addListener(changed);
    body.addListener(changed);
    load();
  }

  Future<void> load() async {
    try {
      final values = await db.getCategories();
      final photos = entry == null
          ? <EntryImage>[]
          : await db.getImagesForEntry(entry!.id!);
      if (!mounted) return;
      setState(() {
        categories = values;
        images = photos;
        ready = true;
        if (!categories.any((e) => e.id == categoryId)) categoryId = null;
        if (entry != null) status = entry!.isDraft ? '已恢复草稿' : '已保存到本机';
      });
    } catch (_) {
      if (mounted) showMessage(context, '加载失败，请返回后重试');
    }
  }

  void changed() {
    dirty = true;
    revision++;
    timer?.cancel();
    if (mounted) setState(() => status = '正在编辑…');
    timer = Timer(const Duration(milliseconds: 700), () => save());
  }

  Future<bool> save({bool publish = false, bool force = false}) {
    timer?.cancel();
    final done = Completer<bool>();
    final savedRevision = revision;
    final snapshot = Entry(
        title: title.text.trim(),
        text: body.text,
        categoryId: categoryId,
        timeCreate: date,
        timeModified: DateTime.now());
    tail = tail.then((_) async {
      if (!force && !publish && !dirty) {
        done.complete(true);
        return;
      }
      if (!force &&
          entry == null &&
          snapshot.title.isEmpty &&
          snapshot.text.trim().isEmpty) {
        done.complete(true);
        return;
      }
      try {
        entry = await db.saveDiary(snapshot.copy(
            id: entry?.id,
            mood: entry?.mood,
            isDraft: publish ? false : (entry?.isDraft ?? true)));
        if (revision == savedRevision) dirty = false;
        if (mounted) {
          setState(() => status = entry!.isDraft ? '草稿已自动保存' : '已保存到本机');
        }
        done.complete(true);
      } catch (_) {
        if (mounted) setState(() => status = '保存失败，请点击右上角重试');
        done.complete(false);
      }
    });
    return done.future;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      save();
    }
  }

  Future<void> close({bool publish = false}) async {
    if (busy || leaving) return;
    if (publish &&
        title.text.trim().isEmpty &&
        body.text.trim().isEmpty &&
        images.isEmpty) {
      showMessage(context, '先写下一句话，或添加一张照片');
      return;
    }
    setState(() => busy = true);
    final ok = await save(publish: publish);
    if (!mounted) return;
    if (!ok) {
      setState(() => busy = false);
      showMessage(context, '保存失败，内容仍在编辑器里，请重试');
      return;
    }
    setState(() => leaving = true);
    // Let PopScope rebuild before popping the route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> addPhotos() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final files =
          await ImagePicker().pickMultiImage(imageQuality: 90, maxWidth: 2400);
      if (files.isEmpty) return;
      if (!await save(force: true)) throw StateError('save');
      for (final file in files) {
        final name = await db.createImg(
            'shiye_${DateTime.now().microsecondsSinceEpoch}_${file.name}',
            await file.readAsBytes());
        if (name == null) throw StateError('photo');
        final image = await db.addImg(
            EntryImage(
                entryId: entry!.id,
                imgPath: name,
                imgRank: images.length,
                timeCreate: DateTime.now()),
            updateStatsAndSync: false);
        images.add(image);
      }
      if (mounted) setState(() => status = '照片已保存到本机');
    } catch (_) {
      if (mounted) showMessage(context, '部分照片未能保存，请检查存储空间后重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    if (entry == null || busy) return;
    if (!await confirm(context, entry!.isDraft ? '删除这篇草稿？' : '删除这篇日记？',
        '文字和日记中的照片副本将被删除，无法撤销。相册原图会保留。')) {
      return;
    }
    if (!mounted) return;
    timer?.cancel();
    setState(() => busy = true);
    await tail;
    try {
      await db.deleteDiary(entry!.id!);
      if (!mounted) return;
      setState(() => leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showMessage(context, '删除失败，请重试');
      }
    }
  }

  Future<void> removePhoto(EntryImage image) async {
    if (!await confirm(context, '移除这张照片？', '只移除日记中的副本，相册里的原图会保留。')) return;
    setState(() => busy = true);
    try {
      await db.removeImg(image, updateData: false);
      images.remove(image);
    } catch (_) {
      if (mounted) showMessage(context, '移除失败，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectDate() async {
    final value = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100));
    if (value != null) {
      setState(() => date =
          DateTime(value.year, value.month, value.day, date.hour, date.minute));
      changed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: leaving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) close();
        },
        child: Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  tooltip: '返回并保存',
                  onPressed: busy ? null : close,
                  icon: const Icon(Icons.arrow_back)),
              title: Text(widget.entry == null ? '写下这一页' : '编辑日记',
                  style: const TextStyle(fontSize: 18)),
              actions: [
                if (entry != null)
                  IconButton(
                      tooltip: entry!.isDraft ? '删除草稿' : '删除日记',
                      onPressed: busy ? null : delete,
                      icon: const Icon(Icons.delete_outline)),
                Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FilledButton(
                        onPressed:
                            ready && !busy ? () => close(publish: true) : null,
                        child: Text(busy ? '保存中' : '完成')))
              ]),
          body: !ready
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 50),
                      children: [
                        TextButton.icon(
                            onPressed: busy ? null : selectDate,
                            style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero),
                            icon: const Icon(Icons.calendar_today_outlined,
                                size: 16),
                            label: Text(diaryDate(date))),
                        const SizedBox(height: 6),
                        TextField(
                            key: const ValueKey('diaryTitle'),
                            controller: title,
                            enabled: !busy,
                            maxLength: 120,
                            maxLines: null,
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                height: 1.4),
                            decoration: const InputDecoration(
                                hintText: '给这一页起个名字',
                                filled: false,
                                counterText: '',
                                contentPadding: EdgeInsets.zero)),
                        const SizedBox(height: 20),
                        Row(children: [
                          Expanded(
                              child: DropdownButtonFormField<int>(
                            value: categoryId ?? -1,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.folder_outlined),
                                labelText: '分类'),
                            items: [
                              const DropdownMenuItem(
                                  value: -1, child: Text('未分类')),
                              for (final category in categories)
                                DropdownMenuItem(
                                    value: category.id,
                                    child: Text(category.name,
                                        overflow: TextOverflow.ellipsis))
                            ],
                            onChanged: busy
                                ? null
                                : (value) {
                                    setState(() => categoryId =
                                        value == -1 ? null : value);
                                    changed();
                                  },
                          )),
                          const SizedBox(width: 8),
                          IconButton(
                              tooltip: '新建分类',
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final id = await categoryDialog(context);
                                      final values = await db.getCategories();
                                      if (!mounted) return;
                                      setState(() {
                                        categories = values;
                                        if (id != null) categoryId = id;
                                      });
                                      if (id != null) changed();
                                    },
                              icon:
                                  const Icon(Icons.create_new_folder_outlined))
                        ]),
                        const SizedBox(height: 24),
                        TextField(
                            key: const ValueKey('diaryBody'),
                            controller: body,
                            enabled: !busy,
                            minLines: 12,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(fontSize: 17, height: 1.85),
                            decoration: const InputDecoration(
                                hintText: '今天读到了什么，遇见了谁？\n把值得留下的，都写在这里。',
                                filled: false,
                                contentPadding: EdgeInsets.zero)),
                        const SizedBox(height: 16),
                        if (images.isNotEmpty)
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            for (var i = 0; i < images.length; i++)
                              SizedBox(
                                  width: 100,
                                  height: 110,
                                  child: Stack(children: [
                                    Positioned.fill(
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: InkWell(
                                                onTap: () => openPhotos(
                                                    context, images, i),
                                                child: LocalImageLoader(
                                                    imagePath:
                                                        images[i].imgPath)))),
                                    Positioned(
                                        right: 0,
                                        top: 0,
                                        child: IconButton.filled(
                                            tooltip: '移除照片',
                                            iconSize: 16,
                                            constraints: const BoxConstraints(
                                                minWidth: 32, minHeight: 32),
                                            onPressed: busy
                                                ? null
                                                : () => removePhoto(images[i]),
                                            icon: const Icon(Icons.close))),
                                  ]))
                          ]),
                        const SizedBox(height: 16),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                                onPressed: busy ? null : addPhotos,
                                icon: const Icon(
                                    Icons.add_photo_alternate_outlined),
                                label: const Text('添加照片'))),
                        const SizedBox(height: 24),
                        Row(children: [
                          const Icon(Icons.check_circle_outline,
                              size: 14, color: muted),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(status,
                                  style: const TextStyle(
                                      fontSize: 12, color: muted))),
                          Text('${body.text.runes.length} 字',
                              style:
                                  const TextStyle(fontSize: 12, color: muted))
                        ]),
                      ]),
                )),
        ),
      );
}
