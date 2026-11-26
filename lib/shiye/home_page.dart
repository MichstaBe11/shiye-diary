import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../entries_database.dart';
import '../models/entry.dart';
import '../models/image.dart';
import '../widgets/local_image_loader.dart';
import 'category.dart';
import 'categories_page.dart';
import 'common.dart';
import 'detail_page.dart';
import 'editor_page.dart';
import 'settings_page.dart';

class JournalHome extends StatefulWidget {
  const JournalHome({super.key});
  @override
  State<JournalHome> createState() => _JournalHomeState();
}

class _JournalHomeState extends State<JournalHome> {
  final search = TextEditingController();
  Timer? debounce;
  List<Entry> entries = [];
  List<DiaryCategory> categories = [];
  Map<int, List<EntryImage>> photos = {};
  int tab = 0;
  int? selected;
  bool uncategorized = false;
  bool loading = true;
  String? error;
  int request = 0;
  int total = 0;
  int today = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ticket = ++request;
    try {
      final values = await EntriesDatabase.instance.getCategories();
      if (selected != null && !values.any((e) => e.id == selected)) {
        selected = null;
      }
      final results = await EntriesDatabase.instance.searchEntries(search.text,
          categoryId: selected, uncategorized: uncategorized);
      final all = await EntriesDatabase.instance.getAllEntries();
      final images = await EntriesDatabase.instance.getAllEntryImages();
      if (!mounted || ticket != request) return;
      setState(() {
        categories = values;
        entries = results;
        photos = {};
        for (final image in images) {
          photos.putIfAbsent(image.entryId!, () => []).add(image);
        }
        total = all.length;
        final now = DateTime.now();
        today = all.where((e) => DateUtils.isSameDay(e.timeCreate, now)).length;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted && ticket == request) {
        setState(() {
          loading = false;
          error = '日记加载失败，请点击重试';
        });
      }
    }
  }

  void filter(int? id, {bool unfiled = false}) {
    setState(() {
      selected = id;
      uncategorized = unfiled;
    });
    load();
  }

  Future<void> write([Entry? entry]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                DiaryEditor(entry: entry, initialCategory: selected)));
    await load();
  }

  Future<void> open(Entry entry) async {
    if (entry.isDraft) {
      await write(entry);
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => DiaryDetail(entry: entry)));
    await load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: switch (tab) {
          1 => CategoriesPage(onSelect: (id) {
              setState(() => tab = 0);
              filter(id, unfiled: id == null);
            }),
          2 => const DiarySettings(),
          _ => diaryList(),
        }),
        floatingActionButton: tab == 0
            ? FloatingActionButton.extended(
                onPressed: () => write(),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('写一页'))
            : null,
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (value) {
              setState(() => tab = value);
              if (value == 0) load();
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: '日记'),
              NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: '分类'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: '我的'),
            ]),
      );

  Widget diaryList() => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('拾页',
                                            style: TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.w700,
                                                color: ink,
                                                letterSpacing: 3)),
                                        SizedBox(height: 6),
                                        Text('收好今天，也收好每个念头。',
                                            style: TextStyle(
                                                fontSize: 13, color: muted)),
                                      ])),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                          color: const Color(0xffe9eee4),
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Column(children: [
                                        Text(
                                            DateFormat('dd')
                                                .format(DateTime.now()),
                                            style: const TextStyle(
                                                fontSize: 24,
                                                color: ink,
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                            DateFormat('M月 EEE', 'zh_CN')
                                                .format(DateTime.now()),
                                            style: const TextStyle(
                                                fontSize: 11, color: ink))
                                      ])),
                                ]),
                            const SizedBox(height: 24),
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                    color: const Color(0xffe9eee4),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Row(children: [
                                  const Icon(Icons.eco_outlined,
                                      size: 34, color: ink),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('已收集 $total 页生活',
                                            style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: ink)),
                                        const SizedBox(height: 4),
                                        Text(
                                            today == 0
                                                ? '今天的故事，等你落笔。'
                                                : '今天留下了 $today 页，真好。',
                                            style: const TextStyle(
                                                fontSize: 12, color: muted)),
                                      ]))
                                ])),
                            const SizedBox(height: 20),
                            TextField(
                                controller: search,
                                onChanged: (_) {
                                  debounce?.cancel();
                                  debounce = Timer(
                                      const Duration(milliseconds: 250), load);
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                    hintText: '搜索标题或正文',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: '清空搜索',
                                            onPressed: () {
                                              search.clear();
                                              load();
                                            },
                                            icon: const Icon(Icons.close)))),
                            const SizedBox(height: 14),
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  categoryChip(
                                      '全部',
                                      selected == null && !uncategorized,
                                      () => filter(null)),
                                  for (final category in categories)
                                    categoryChip(
                                        category.name,
                                        selected == category.id &&
                                            !uncategorized,
                                        () => filter(category.id)),
                                  categoryChip('未分类', uncategorized,
                                      () => filter(null, unfiled: true)),
                                ])),
                            const SizedBox(height: 16),
                            Row(children: [
                              Text(
                                  search.text.trim().isEmpty ? '最近的日记' : '搜索结果',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: ink)),
                              const Spacer(),
                              Text('${entries.length} 篇',
                                  style: const TextStyle(
                                      fontSize: 12, color: muted))
                            ]),
                            const SizedBox(height: 12),
                          ]))),
              if (loading)
                const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator())))
              else if (error != null)
                SliverToBoxAdapter(
                    child: TextButton(onPressed: load, child: Text(error!)))
              else if (entries.isEmpty)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(children: [
                          const Icon(Icons.menu_book_outlined,
                              size: 56, color: ink),
                          const SizedBox(height: 16),
                          Text(search.text.isEmpty ? '这一页，留给你。' : '没有找到相关日记',
                              style: const TextStyle(fontSize: 20, color: ink)),
                          const SizedBox(height: 10),
                          Text(
                              search.text.isEmpty
                                  ? '写一段文字，或收藏一张照片。'
                                  : '试试其他关键词，或切换到“全部”。',
                              style: const TextStyle(color: muted)),
                          const SizedBox(height: 18),
                          if (search.text.isEmpty)
                            OutlinedButton(
                                onPressed: () => write(),
                                child: const Text('开始第一篇日记')),
                        ])))
              else
                SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    sliver: SliverList.builder(
                        itemCount: entries.length,
                        itemBuilder: (_, index) => entryCard(entries[index]))),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ]),
          )));

  Widget categoryChip(String name, bool active, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          label: Text(name),
          selected: active,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          side: BorderSide.none,
          selectedColor: ink,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(color: active ? Colors.white : muted),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  Widget entryCard(Entry entry) {
    final category =
        categories.where((c) => c.id == entry.categoryId).firstOrNull?.name ??
            '未分类';
    final images = photos[entry.id] ?? [];
    return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: () => open(entry),
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(DateFormat('MM.dd').format(entry.timeCreate),
                            style: const TextStyle(color: muted, fontSize: 12)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(category,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontSize: 12, color: ink))),
                        if (entry.isDraft)
                          const Text('草稿',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xff98673b))),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          entry.title.isEmpty
                              ? (entry.text.trim().isEmpty
                                  ? '照片日记'
                                  : entry.text.trim().split('\n').first)
                              : entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: Color(0xff2d382f))),
                      if (entry.text.trim().isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(entry.text.trim(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, height: 1.7, color: muted))),
                      if (images.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: SizedBox(
                                height: 100,
                                child: Row(children: [
                                  for (final image in images.take(3))
                                    Expanded(
                                        child: Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6),
                                            child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: LocalImageLoader(
                                                    imagePath:
                                                        image.imgPath)))),
                                  if (images.length > 3)
                                    Text('+${images.length - 3}',
                                        style: const TextStyle(color: muted)),
                                ]))),
                    ]))));
  }
}
