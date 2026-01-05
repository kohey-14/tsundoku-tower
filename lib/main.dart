import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '積読バスター',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF9F8F4), // オフホワイト
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC0392B), // 赤
          primary: const Color(0xFFC0392B),
          surface: const Color(0xFFF9F8F4),
        ),
        // ポップなフォント設定
        textTheme: GoogleFonts.zenKakuGothicNewTextTheme(
          Theme.of(context).textTheme,
        ).apply(
          bodyColor: const Color(0xFF333333),
          displayColor: const Color(0xFF333333),
        ),
        // ヘッダーの設定
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF9F8F4),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.delaGothicOne(
            color: const Color(0xFF222222),
            fontSize: 24,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF222222)),
          shape: const Border(bottom: BorderSide(color: Color(0xFF222222), width: 3)),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}