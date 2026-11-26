import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home_page.dart';
import 'common.dart';

class ShiyeApp extends StatelessWidget {
  const ShiyeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '拾页日记',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(
              seedColor: ink, primary: ink, surface: paper),
          appBarTheme: const AppBarTheme(
              backgroundColor: paper,
              foregroundColor: ink,
              centerTitle: false,
              elevation: 0),
          cardTheme: CardTheme(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none)),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: ink, foregroundColor: Colors.white),
        ),
        home: const JournalHome(),
      );
}
