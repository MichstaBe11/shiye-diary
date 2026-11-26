import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../entries_database.dart';
import '../models/image.dart';
import '../widgets/local_image_loader.dart';

const ink = Color(0xff304f41);
const paper = Color(0xfff7f6f1);
const muted = Color(0xff777d73);

String diaryDate(DateTime date) =>
    DateFormat('yyyy年M月d日 · EEEE', 'zh_CN').format(date);

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirm(
        BuildContext context, String title, String message) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认')),
              ],
            )) ??
    false;

Future<int?> categoryDialog(BuildContext context,
    {int? id, String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  var busy = false;
  String? error;
  final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(id == null ? '新建分类' : '重命名分类'),
              content: Form(
                  key: form,
                  child: TextFormField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 20,
                    decoration:
                        InputDecoration(hintText: '例如：旅行见闻', errorText: error),
                    validator: (value) {
                      try {
                        EntriesDatabase.validateCategoryName(value ?? '');
                        return null;
                      } on FormatException catch (e) {
                        return e.message;
                      }
                    },
                  )),
              actions: [
                TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            update(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              final saved = await EntriesDatabase.instance
                                  .saveCategory(controller.text, id: id);
                              if (context.mounted) {
                                Navigator.pop(context, saved);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                update(() {
                                  busy = false;
                                  error = e is FormatException
                                      ? e.message
                                      : '保存失败，请重试';
                                });
                              }
                            }
                          },
                    child: const Text('保存')),
              ],
            ),
          ));
  // The closing route still uses its text field during the dismissal animation.
  Future.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}

void openPhotos(BuildContext context, List<EntryImage> images, int initial) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    title: const Text('照片')),
                body: PageView.builder(
                  controller: PageController(initialPage: initial),
                  itemCount: images.length,
                  itemBuilder: (context, index) => InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Center(
                          child: LocalImageLoader(
                              imagePath: images[index].imgPath,
                              cacheSize: 1600))),
                ),
              )));
}
