# 拾页日记 0.1.0

一个只面向 Android 的中文本地日记初版。基于 [Daily You v2.7.1](https://github.com/Demizo/Daily_You/tree/v2.7.1) 修改，原作者为 Demizo 及贡献者。这是独立修改版，并非 Daily You 官方应用。沿用 GNU GPL v3，完整许可证见 `LICENSE.txt`，上游项目介绍见 [原始 README](README_UPSTREAM.md)。

## 已实现

1. 写日记：标题、正文、日期、新建、阅读、编辑和确认删除。
2. 多张照片：通过 Android 相册选择，复制到应用目录，预览、缩放和确认移除。不会删除相册原图。
3. 单层分类：预设阅读摘要、人物故事、感悟随笔、灵感、待办；支持新增、重命名、长按排序和确认删除。每篇归属一个分类，删除分类后日记归入“未分类”。“待办”是普通分类。
4. 搜索与草稿：搜索标题和正文，可叠加分类筛选。停止输入 700 毫秒后自动保存，返回及切到后台时也尝试保存。草稿显示在列表里，点击继续写，点“完成”发布。
5. 备份：在“我的”导出 ZIP，包含日记、分类和照片；导入时将日记作为副本添加，同名分类合并，保留本机已有内容。

## 使用与数据

将 APK 传到手机后安装；最低 Android 6.0（API 23）。手机首次通过文件安装时可能需要为文件管理器开启“允许安装未知应用”。

应用不需要账号，不包含云同步。文字、草稿和照片存放在应用专属目录，卸载会被 Android 清除。请定期在“我的 → 导出备份”保存到其他目录或自己的云盘。

备份不加密，内容总大小上限 100 MB。重复导入同一备份会产生副本，导入前会明确提示。本版只能读取拾页自己的 ZIP 格式，不支持直接导入新版 Daily You 的备份。

## 开发与构建

已固定为 Flutter 3.29.3 / Dart 3.7.2；Android Gradle Plugin 8.7.3、Gradle 8.10.2、Kotlin 2.1.0。构建使用 JDK 21、Android SDK 35、NDK 27.0.12077973。首次构建需要联网下载依赖。锁定的 `pubspec.lock` 应保留。

默认入口 `lib/main.dart` 会启动 `lib/shiye_main.dart`，直接运行 `flutter run` 即可。旧启动代码保留为 `lib/upstream_main.dart`，旧界面仍保留。其他系统的平台工程已移到 `upstream-platforms/`，避免 Android 构建要求 Windows 符号链接权限。

```powershell
flutter pub get
flutter analyze lib/shiye lib/shiye_main.dart lib/models/entry.dart lib/entries_database.dart lib/file_bytes_cache.dart test integration_test test_driver
flutter test test/shiye_database_test.dart
flutter build apk --release --target lib/shiye_main.dart
```

生成的安装包位于 `build/app/outputs/flutter-apk/app-release.apk`。本版使用开发测试签名，可安装试用；正式发布前需配置专用签名，并保管好密钥。

如果 Flutter、Android SDK、JDK 不在默认位置，可以运行：

```powershell
./build-shiye.ps1 -FlutterSdk 'D:/tools/flutter' -AndroidSdk 'D:/Android/Sdk' -JavaHome 'D:/tools/jdk-21'
```

## 测试与界面验证

数据测试覆盖预设及自定义分类、重名校验、排序、中文及字面搜索、分类删除保留内容、草稿持久保存、v3 数据升级、备份解析校验，以及文字/分类/照片导出恢复。

完整 Android 流程测试位于 `integration_test/app_test.dart`。必须在专用、没有日记数据的测试设备上运行：

```powershell
flutter drive --driver test_driver/integration_test.dart --target integration_test/app_test.dart -d DEVICE_ID
```

截图写入 `build/screenshots/`。该测试会创建并删除自己的测试日记，不能在存有真实日记的设备上运行。

## 本次修改位置

`lib/shiye/` 为中文首页、编辑器、阅读页、分类管理、备份与设置。`lib/models/entry.dart` 增加标题、分类和草稿字段；`lib/entries_database.dart` 增加数据库 v4 升级、分类管理、搜索和备份合并。Android 应用 ID 改为 `app.shiye.diary`，名称与图标均独立于原版。

上游 Git 依赖 `media_scanner` 已移除，日记照片不再触发系统相册扫描。构建依赖、旧平台工程及许可证仍保留在源码中，方便继续维护。
