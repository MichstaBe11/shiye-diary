import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'backup.dart';
import 'common.dart';

class DiarySettings extends StatefulWidget {
  const DiarySettings({super.key});
  @override
  State<DiarySettings> createState() => _DiarySettingsState();
}

class _DiarySettingsState extends State<DiarySettings> {
  bool busy = false;
  String status = '';

  Future<void> backup() async {
    setState(() {
      busy = true;
      status = '正在打包文字、分类和照片…';
    });
    try {
      final bytes = await DiaryBackup.export();
      final path = await FilePicker.platform.saveFile(
          dialogTitle: '保存日记备份',
          fileName:
              '拾页备份_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
          bytes: bytes);
      if (mounted) showMessage(context, path == null ? '已取消备份' : '备份已导出，请妥善保管');
    } catch (e) {
      if (mounted) {
        showMessage(
            context, e is FormatException ? e.message : '备份失败，请检查可用空间后重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          status = '';
        });
      }
    }
  }

  Future<void> restore() async {
    setState(() {
      busy = true;
      status = '请选择拾页备份文件';
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) return;
      final path = result.files.single.path;
      if (path == null) throw const FormatException('无法读取所选文件');
      final file = File(path);
      if (await file.length() > DiaryBackup.maxBytes) {
        throw const FormatException('备份文件超过 100 MB');
      }
      final bytes = await file.readAsBytes();
      final data = DiaryBackup.parse(bytes);
      if (!mounted ||
          !await confirm(context, '导入 ${data.entries.length} 篇日记？',
              '日记将作为副本添加，同名分类会合并，现有内容会保留。重复导入同一备份会产生重复日记。')) {
        return;
      }
      if (mounted) setState(() => status = '正在恢复日记和照片，请保持应用开启…');
      final count = await DiaryBackup.restore(bytes);
      if (mounted) showMessage(context, '已导入 $count 篇日记');
    } catch (e) {
      if (mounted) {
        showMessage(
            context, e is FormatException ? e.message : '导入失败，请确认文件是完整的拾页备份');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          const Icon(Icons.auto_stories, size: 56, color: ink),
          const SizedBox(height: 12),
          const Text('拾页日记',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 27, color: ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('把日子过成值得翻阅的书。',
              textAlign: TextAlign.center, style: TextStyle(color: muted)),
          const SizedBox(height: 30),
          Card(
              child: Column(children: [
            ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('导出备份'),
                subtitle: const Text('包含文字、分类与照片'),
                onTap: busy ? null : backup,
                trailing: const Icon(Icons.chevron_right)),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('导入备份'),
                subtitle: const Text('合并内容，保留现有日记'),
                onTap: busy ? null : restore,
                trailing: const Icon(Icons.chevron_right)),
          ])),
          if (busy)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(status)
                ])),
          const SizedBox(height: 16),
          const Text('只留在你的手机',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: ink)),
          const SizedBox(height: 10),
          const Text('不需要账号，日记和照片保存在本机。卸载应用会清除本机内容，请定期导出备份。备份未加密，建议保存在自己的安全位置。',
              style: TextStyle(color: muted, height: 1.7)),
          const SizedBox(height: 24),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于与开源许可'),
                  subtitle: const Text('0.1.0 · 基于 Daily You 修改'),
                  onTap: () => showAboutDialog(
                          context: context,
                          applicationName: '拾页日记',
                          applicationVersion: '0.1.0 试用版',
                          applicationLegalese:
                              '基于 Daily You v2.7.1（Demizo 及贡献者）修改。\n这是独立修改版，并非 Daily You 官方应用。\n按 GNU GPL v3 分发，源代码随安装包提供。',
                          children: [
                            TextButton(
                                onPressed: () => launchUrl(Uri.parse(
                                    'https://github.com/Demizo/Daily_You')),
                                child: const Text('查看原始开源项目'))
                          ]))),
          const SizedBox(height: 12),
          const Text('初版备份总内容上限 100 MB。',
              style: TextStyle(color: muted, fontSize: 12)),
        ]),
      );
}
