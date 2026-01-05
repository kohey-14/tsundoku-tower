import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart'; // ★CSV共有用
import 'package:intl/intl.dart'; // ★日付フォーマット用
import '../models/book.dart';
import '../services/storage_service.dart';

enum SortType { title, author, dateDesc }

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  List<Book> finishedBooks = [];
  final StorageService _storageService = StorageService();
  SortType _currentSort = SortType.dateDesc;

  @override
  void initState() {
    super.initState();
    _loadFinishedBooks();
  }

  Future<void> _loadFinishedBooks() async {
    final books = await _storageService.loadFinishedBooks();
    setState(() {
      finishedBooks = books;
    });
    _sortBooks(_currentSort);
  }

  void _sortBooks(SortType type) {
    setState(() {
      _currentSort = type;
      switch (type) {
        case SortType.title:
          finishedBooks.sort((a, b) => a.title.compareTo(b.title));
          break;
        case SortType.author:
          finishedBooks.sort((a, b) => a.author.compareTo(b.author));
          break;
        case SortType.dateDesc:
          finishedBooks.sort((a, b) => a.title.compareTo(b.title));
          break;
      }
    });
  }

  Future<void> _deleteFromShelf(int index) async {
    setState(() {
      finishedBooks.removeAt(index);
    });
    await _storageService.saveFinishedBooks(finishedBooks);
  }

  // ★CSVアーカイブ作成＆リセット処理
  Future<void> _archiveAndReset() async {
    if (finishedBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本棚は空です')),
      );
      return;
    }

    // 1. CSVデータの作成
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('タイトル,著者,ページ数,アーカイブ日時'); // ヘッダー
    
    final String dateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());
    for (final book in finishedBooks) {
      // カンマを含むタイトル対策としてダブルクォートで囲むのが安全
      csvBuffer.writeln('"${book.title}","${book.author}",${book.pageCount},$dateStr');
    }

    // 2. 共有（Share）
    final String csvData = csvBuffer.toString();
    
    // Web(Chrome)の場合、ファイル保存は難しいのでテキストとして共有・コピーさせます
    try {
      await Share.share(
        csvData,
        subject: '読了本棚アーカイブ_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (e) {
      // Webなどでシェア機能がキャンセルされた場合など
      debugPrint('Share cancelled or failed: $e');
    }

    // 3. リセット確認ダイアログ
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本棚をリセットしますか？'),
        content: const Text('CSVデータを保存しましたか？\n「はい」を押すと、現在の本棚は空になります。\n（新しい本棚の始まりです！）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('いいえ（残す）'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // ダイアログを閉じる
              // データ消去
              setState(() {
                finishedBooks.clear();
              });
              await _storageService.saveFinishedBooks(finishedBooks);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('本棚をリセットしました！')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('はい（空にする）'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalTitle(String title, Color textColor, double bookHeight) {
    const double fontSize = 10.0;
    const double lineHeight = 1.1;
    const double charHeight = fontSize * lineHeight;
    const double reservedSpace = 35.0; 
    final double availableHeight = bookHeight - reservedSpace;
    final int maxChars = (availableHeight / charHeight).floor();

    String displayTitle = title;
    if (title.length > maxChars) {
      displayTitle = "${title.substring(0, maxChars > 1 ? maxChars - 1 : 1)}…";
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: displayTitle.split('').map((char) {
        return Text(
          char,
          style: GoogleFonts.zenKakuGothicNew(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: lineHeight,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShelfSpine(Book book, int index) {
    final double width = (book.pageCount / 10).clamp(22.0, 55.0);
    final int heightVariant = book.id.hashCode % 3;
    final double height = [120.0, 135.0, 155.0][heightVariant];
    final Color baseColor = book.spineColor ?? Colors.grey;
    final bool isDark = baseColor.computeLuminance() < 0.5;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color borderColor = Colors.black.withOpacity(0.8);

    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('『${book.title}』を削除しますか？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              TextButton(onPressed: () {
                Navigator.pop(context);
                _deleteFromShelf(index);
              }, child: const Text('削除', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      child: Tooltip(
        message: "${book.title}\n${book.author}",
        child: Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(2),
              bottomLeft: Radius.circular(1),
              bottomRight: Radius.circular(1),
            ),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: const Offset(1, 1))],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: _buildVerticalTitle(book.title, textColor, height),
                ),
              ),
              Positioned(
                bottom: 6, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: width * 0.5, height: width * 0.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: textColor.withOpacity(0.5), width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: Text("${book.pageCount}", style: TextStyle(fontSize: 6, color: textColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEBE9), 
      appBar: AppBar(
        title: const Text('読了した本棚'),
        backgroundColor: const Color(0xFFEFEBE9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: GoogleFonts.zenKakuGothicNew(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        actions: [
          // ★アーカイブボタン追加
          IconButton(
            icon: const Icon(Icons.archive, color: Colors.black54),
            tooltip: 'CSV出力してリセット',
            onPressed: _archiveAndReset,
          ),
          // 並べ替えボタン
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort, color: Colors.black),
            onSelected: _sortBooks,
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortType.title, child: Text('作品名順')),
              const PopupMenuItem(value: SortType.author, child: Text('作家名順')),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: finishedBooks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shelves, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'まだ本棚は空っぽです\n読み終わった本を\nここに並べていこう！',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.zenKakuGothicNew(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, bottom: 40, left: 16, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF8D6E63), width: 8.0)),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 0,
                      runSpacing: 24,
                      children: List.generate(finishedBooks.length, (index) {
                        return _buildShelfSpine(finishedBooks[index], index);
                      }),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}