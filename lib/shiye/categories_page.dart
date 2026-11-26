import 'package:flutter/material.dart';
import '../entries_database.dart';
import 'category.dart';
import 'common.dart';

class CategoriesPage extends StatefulWidget {
  final void Function(int?) onSelect;
  const CategoriesPage({super.key, required this.onSelect});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<DiaryCategory> categories = [];
  Map<int?, int> counts = {};
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await EntriesDatabase.instance.getCategories();
      final entries = await EntriesDatabase.instance.getAllEntries();
      if (!mounted) return;
      setState(() {
        categories = values;
        counts = {};
        for (final entry in entries) {
          counts.update(entry.categoryId, (n) => n + 1, ifAbsent: () => 1);
        }
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        showMessage(context, '分类加载失败，请重试');
      }
    }
  }

  Future<void> add() async {
    await categoryDialog(context);
    await load();
  }

  Future<void> action(DiaryCategory category, String action) async {
    if (action == 'rename') {
      await categoryDialog(context, id: category.id, initial: category.name);
    } else {
      if (!await confirm(
          context, '删除“${category.name}”？', '分类中的日记会移到“未分类”，文字和照片都会保留。')) {
        return;
      }
      try {
        await EntriesDatabase.instance.deleteCategory(category.id);
      } catch (_) {
        if (mounted) showMessage(context, '删除失败，请重试');
      }
    }
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('我的分类'), actions: [
          IconButton(
              tooltip: '新建分类',
              onPressed: busy ? null : add,
              icon: const Icon(Icons.add))
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ReorderableListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                header: Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('给每一种想法\n留一个位置。',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: ink)),
                          const SizedBox(height: 12),
                          const Text('长按拖动调整顺序 · 点击分类查看日记',
                              style: TextStyle(color: muted)),
                          const SizedBox(height: 20),
                          Card(
                              child: ListTile(
                                  leading: const Icon(Icons.inbox_outlined),
                                  title: const Text('未分类'),
                                  subtitle: Text('${counts[null] ?? 0} 篇日记'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => widget.onSelect(null))),
                        ])),
                onReorder: (oldIndex, newIndex) async {
                  if (busy) return;
                  if (newIndex > oldIndex) {
                    newIndex--;
                  }
                  setState(() {
                    busy = true;
                    final item = categories.removeAt(oldIndex);
                    categories.insert(newIndex, item);
                  });
                  try {
                    await EntriesDatabase.instance.reorderCategories(
                        categories.map((e) => e.id).toList());
                  } catch (_) {
                    if (context.mounted) showMessage(context, '排序保存失败，请重试');
                  }
                  if (mounted) setState(() => busy = false);
                  await load();
                },
                children: [
                  for (final category in categories)
                    Card(
                        key: ValueKey(category.id),
                        child: ListTile(
                          leading:
                              const Icon(Icons.folder_outlined, color: ink),
                          title: Text(category.name),
                          subtitle: Text('${counts[category.id] ?? 0} 篇日记'),
                          onTap: () => widget.onSelect(category.id),
                          trailing: PopupMenuButton<String>(
                              tooltip: '管理分类',
                              enabled: !busy,
                              onSelected: (value) => action(category, value),
                              itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'rename', child: Text('重命名')),
                                    PopupMenuItem(
                                        value: 'delete', child: Text('删除分类')),
                                  ]),
                        ))
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: busy ? null : add,
            icon: const Icon(Icons.add),
            label: const Text('新建分类')),
      );
}
