import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class StorageService {
  static const String _booksKey = 'tsundoku_books';
  static const String _finishedKey = 'tsundoku_finished';
  static const String _historyKey = 'tsundoku_history';

  // 保存
  Future<void> saveBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(books.map((b) => b.toJson()).toList());
    await prefs.setString(_booksKey, data);
  }

  // 読み込み
  Future<List<Book>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_booksKey);
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => Book.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFinishedBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(books.map((b) => b.toJson()).toList());
    await prefs.setString(_finishedKey, data);
  }

  Future<List<Book>> loadFinishedBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_finishedKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((json) => Book.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveReadHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, history);
  }

  Future<List<String>> loadReadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }
}