// Modified version of Daily You v2.7.1 by Demizo and contributors, GPL-3.0.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'config_provider.dart';
import 'entries_database.dart';
import 'shiye/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['拾页日记 / Daily You'], await rootBundle.loadString('LICENSE.txt'));
  });
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  try {
    await initializeDateFormatting('zh_CN');
    await ConfigProvider.instance.init();
    await EntriesDatabase.instance.initDB(forceWithoutSync: true);
    runApp(const ShiyeApp());
  } catch (_) {
    runApp(MaterialApp(
        home: Scaffold(
            body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('暂时无法打开日记，请关闭应用后重试。\n原有数据未被清除。', textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(onPressed: main, child: const Text('重试')),
    ])))));
  }
}
