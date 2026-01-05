import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/book.dart';

class BookService {
  // 本っぽい色のリスト
  static const List<Color> _bookColors = [
    Color(0xFF8D6E63), // 茶
    Color(0xFFD32F2F), // 赤
    Color(0xFF1976D2), // 青
    Color(0xFF388E3C), // 緑
    Color(0xFFFBC02D), // 黄
    Color(0xFF7B1FA2), // 紫
    Color(0xFF455A64), // ブルーグレー
    Color(0xFFE64A19), // オレンジ
    Color(0xFF5D4037), // 濃茶
    Color(0xFF263238), // 黒灰
  ];

  // Google Books APIを使って本を検索
  Future<Book?> fetchBookByIsbn(String isbn) async {
    // Google Books APIのURL
    final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // "items" というリストがあればヒット
        if (data['totalItems'] > 0 && data['items'] != null) {
          final item = data['items'][0];
          final info = item['volumeInfo']; // ここに情報が入っている
          
          // --- データの取得 ---
          
          // タイトル
          final title = info['title'] ?? 'タイトル不明';
          
          // 著者（リストになっているのでカンマ区切りにする）
          String author = '著者不明';
          if (info['authors'] != null) {
            author = (info['authors'] as List).join(', ');
          }

          // 画像URL（http を https に変換しておくと安全）
          String imageUrl = '';
          if (info['imageLinks'] != null && info['imageLinks']['thumbnail'] != null) {
            imageUrl = info['imageLinks']['thumbnail'].toString().replaceFirst('http:', 'https:');
          }

          // ★ページ数（Google Booksは数値で持っていることが多い！）
          int pageCount = info['pageCount'] ?? 0;
          
          // もし万が一ページ数が0なら、ランダムにする（バックアップ策）
          if (pageCount == 0) {
             pageCount = Random().nextInt(300) + 150;
          }

          // ランダム色
          final randomColor = _bookColors[Random().nextInt(_bookColors.length)];

          return Book(
            id: isbn,
            title: title,
            author: author,
            imageUrl: imageUrl,
            spineColor: randomColor,
            addedDate: DateTime.now(),
            pageCount: pageCount,
          );
        }
      }
    } catch (e) {
      print('検索エラー: $e');
    }
    return null;
  }
}