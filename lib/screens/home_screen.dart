import 'dart:convert';
import 'dart:math'; // ランダム幅用
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../models/book.dart';
import '../services/storage_service.dart';
import 'search_screen.dart';
import 'bookshelf_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // データ管理
  List<Book> books = [];
  List<Book> finishedBooks = [];
  List<String> readHistory = [];
  
  final StorageService _storageService = StorageService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ★デザイン定数
  final double _borderWidth = 2.0; 
  final BoxShadow _comicShadow = const BoxShadow(
    color: Colors.black,
    offset: Offset(3, 3),
    blurRadius: 0,
  );

  TextStyle _getComicFont({
    double size = 16,
    Color color = Colors.black,
    bool isTitle = false, 
  }) {
    if (isTitle) {
      return GoogleFonts.delaGothicOne(fontSize: size, color: color);
    } else {
      return GoogleFonts.mPlusRounded1c(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w800,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String soundFileName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundFileName'));
    } catch (e) {
      debugPrint('効果音エラー（ファイルがないかも）: $e');
    }
  }

  Future<void> _loadData() async {
    final loadedBooks = await _storageService.loadBooks();
    final loadedFinished = await _storageService.loadFinishedBooks();
    final loadedHistory = await _storageService.loadReadHistory();
    setState(() {
      books = loadedBooks;
      finishedBooks = loadedFinished;
      readHistory = loadedHistory;
    });
  }

  Future<void> _saveAll() async {
    await _storageService.saveBooks(books);
    await _storageService.saveFinishedBooks(finishedBooks);
    await _storageService.saveReadHistory(readHistory);
  }

  Future<void> _addBookLogic(Book newBook) async {
    final bool isAlreadyStacked = books.any((b) => b.id == newBook.id);
    if (isAlreadyStacked) {
      if (!mounted) return;
      _showComicDialog('重複！', '『${newBook.title}』は\n既に積まれていますよ。', isError: true);
      return;
    }

    final bool isReadBefore = finishedBooks.any((b) => b.id == newBook.id);
    if (isReadBefore) {
      if (!mounted) return;
      final bool? shouldAdd = await showDialog<bool>(
        context: context,
        builder: (context) => _buildComicAlertDialog(
          title: '読了済み',
          content: '『${newBook.title}』は読み終わっています。\nもう一度積みますか？',
          onConfirm: () => Navigator.pop(context, true),
          confirmText: 'もう一度！',
          confirmColor: const Color(0xFFFF5252),
        ),
      );
      if (shouldAdd != true) return;
    }

    setState(() {
      books.add(newBook);
    });
    await _saveAll();
    _playSound('add_book.mp3');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('『${newBook.title}』を積みました！', style: _getComicFont(color: Colors.white)),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _addBookFromSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
    if (result != null && result is Book) {
      await _addBookLogic(result);
    }
  }

// ★修正: 連打防止機能付きのスキャン処理
  Future<void> _scanBarcode() async {
    // ★重要: 「読み取り済みフラグ」を用意
    bool isScanned = false;

    final String? barcode = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('バーコードスキャン', style: _getComicFont(isTitle: true))),
          body: MobileScanner(
            onDetect: (capture) {
              // ★もし既に読み取っていたら、何もしないで帰る（ガード！）
              if (isScanned) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                // ISBN(978)のみ反応
                if (barcode.rawValue != null && barcode.rawValue!.startsWith('978')) {
                  // ★読み取り済みフラグをONにする（これで2回目は反応しない）
                  isScanned = true;
                  Navigator.pop(context, barcode.rawValue);
                  return;
                }
              }
            },
          ),
        ),
      ),
    );

    if (barcode != null) {
      await _fetchAndAddBookByIsbn(barcode);
    }
  }
  
  Future<void> _fetchAndAddBookByIsbn(String isbn) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.black)),
    );

    try {
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['totalItems'] > 0) {
          final item = data['items'][0];
          final info = item['volumeInfo'];
          
          final newBook = Book(
            id: item['id'],
            title: info['title'] ?? '不明なタイトル',
            author: (info['authors'] as List?)?.join(', ') ?? '不明な著者',
            imageUrl: (info['imageLinks'] != null && info['imageLinks']['thumbnail'] != null)
                ? info['imageLinks']['thumbnail']
                : '',
            pageCount: info['pageCount'] ?? 200,
            addedDate: DateTime.now(),
          );
          
          if (!mounted) return;
          Navigator.pop(context); // ローディング消去
          await _addBookLogic(newBook);
        } else {
          throw Exception('該当なし');
        }
      } else {
        throw Exception('通信エラー');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ローディング消去
      _showComicDialog('エラー', '情報の取得に失敗しました…。\n$e', isError: true);
    }
  }

  Future<void> _finishBook(int index) async {
    final finishedBook = books[index];
    setState(() {
      books.removeAt(index);
      finishedBooks.insert(0, finishedBook);
    });
    await _saveAll();
    _playSound('finish_book.mp3');

    if (!mounted) return;
    _showComicSnackBar(
      context,
      'COMPLETE!',
      '『${finishedBook.title}』\n読破おめでとうございます！',
      onUndo: () {
        setState(() {
          finishedBooks.removeAt(0);
          if (index <= books.length) {
            books.insert(index, finishedBook);
          } else {
            books.add(finishedBook);
          }
        });
        _saveAll();
      },
    );
  }

  Future<void> _deleteBook(int index) async {
    final deletedBook = books[index];
    final bool wasInHistory = readHistory.contains(deletedBook.id);
    setState(() {
      books.removeAt(index);
      if (!wasInHistory) readHistory.add(deletedBook.id);
    });
    await _saveAll();
    _playSound('delete_book.mp3');

    if (!mounted) return;
    _showComicSnackBar(
      context,
      'DELETED',
      '『${deletedBook.title}』\n削除しました。',
      isDelete: true,
      onUndo: () {
        setState(() {
          if (index <= books.length) {
            books.insert(index, deletedBook);
          } else {
            books.add(deletedBook);
          }
          if (!wasInHistory) readHistory.remove(deletedBook.id);
        });
        _saveAll();
      },
    );
  }

  // --- UIパーツ ---

  void _openBookshelf() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BookshelfScreen()),
    ).then((_) {
      _loadData();
    });
  }

  void _showComicDialog(String title, String content, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => _buildComicAlertDialog(
        title: title,
        content: content,
        titleColor: isError ? Colors.red : Colors.black,
      ),
    );
  }

  void _showComicSnackBar(BuildContext context, String title, String message, {required VoidCallback onUndo, bool isDelete = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: _borderWidth),
            boxShadow: [_comicShadow],
          ),
          child: Row(
            children: [
              Icon(
                isDelete ? Icons.delete : Icons.check_circle,
                color: isDelete ? Colors.red : Colors.blue,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: _getComicFont(size: 14, isTitle: true)),
                    Text(message, style: _getComicFont(size: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onUndo,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD740),
                  side: const BorderSide(color: Colors.black, width: 2),
                ),
                child: Text('元に戻す', style: _getComicFont(color: Colors.black, size: 10, isTitle: true)),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ★修正: オーバーフロー対策済みのダイアログ
  Widget _buildComicAlertDialog({
    required String title,
    required String content,
    Color titleColor = Colors.black,
    VoidCallback? onConfirm,
    String? confirmText,
    Color? confirmColor,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      scrollable: true, // ★追加: これで画面からはみ出なくなる！
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Colors.black, width: _borderWidth),
      ),
      title: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
        ),
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: _getComicFont(color: titleColor, size: 20, isTitle: true)),
      ),
      content: Text(content, style: _getComicFont(size: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('閉じる', style: _getComicFont(color: Colors.grey, isTitle: true)),
        ),
        if (onConfirm != null)
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? const Color(0xFF448AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(color: Colors.black, width: _borderWidth),
              ),
              elevation: 0,
            ).copyWith(
              shadowColor: MaterialStateProperty.all(Colors.black),
              elevation: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.pressed) ? 0.0 : 4.0),
            ),
            child: Text(confirmText ?? 'OK', style: _getComicFont(color: Colors.white, isTitle: true)),
          ),
      ],
    );
  }

  Widget _buildStatsArea() {
    final int totalPages = books.fold(0, (sum, book) => sum + book.pageCount);
    final double heightCm = totalPages * 0.01; 

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: _borderWidth),
        boxShadow: [_comicShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOWER HEIGHT', style: _getComicFont(size: 10, color: Colors.grey)),
              Text('${heightCm.toStringAsFixed(1)} cm', style: _getComicFont(size: 24, isTitle: true)),
            ],
          ),
          const Icon(Icons.arrow_upward, size: 30, color: Colors.black),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TOTAL PAGES', style: _getComicFont(size: 10, color: Colors.grey)),
              Text('$totalPages P', style: _getComicFont(size: 24, isTitle: true, color: Colors.blueAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookSpine(Book book, int index) {
    final double spineHeight = (book.pageCount / 7).clamp(30.0, 80.0);
    final int randomSeed = book.id.hashCode;
    final double bookWidth = 50.0 + (randomSeed % 30).toDouble();
    final Color baseColor = book.spineColor ?? Colors.primaries[randomSeed % Colors.primaries.length];
    
    return Center(
      child: Tooltip(
        message: "${book.title}\n(${book.pageCount}p / 著者: ${book.author})",
        textStyle: _getComicFont(size: 12, color: Colors.white),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1),
        ),
        preferBelow: false,
        child: Container(
          width: bookWidth,
          height: spineHeight,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: baseColor,
            border: Border.all(color: Colors.black, width: _borderWidth),
            boxShadow: [_comicShadow],
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(3)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0, top: 0, bottom: 0, width: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    border: const Border(right: BorderSide(color: Colors.black, width: 1)),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showComicDialog(book.title, '${book.pageCount}ページ\n著者: ${book.author}'),
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
      // ★修正: キーボード等の影響を受けないようにする設定
      resizeToAvoidBottomInset: false,
      
      appBar: AppBar(
        centerTitle: true,
        title: Text('TSUNDOKU TOWER', style: _getComicFont(color: Colors.black, size: 22, isTitle: true)),
        backgroundColor: Colors.white,
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 2)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu, color: Colors.black),
            onPressed: _openBookshelf,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'), 
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            _buildStatsArea(),
            Expanded(
              child: books.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_clear, size: 50, color: Colors.black54),
                            const SizedBox(height: 10),
                            Text(
                              'NO TOWER!',
                              style: _getComicFont(size: 20, color: Colors.black, isTitle: true),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      // iPhoneのホームバーを避ける余白設定
                      padding: const EdgeInsets.only(bottom: 60, top: 100),
                      reverse: true,
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return Dismissible(
                          key: ObjectKey(book), 
                          background: Container(
                            color: const Color(0xFF448AFF).withOpacity(0.8),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: const Color(0xFFFF5252).withOpacity(0.8),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            if (direction == DismissDirection.startToEnd) {
                              _finishBook(index);
                            } else {
                              _deleteBook(index);
                            }
                          },
                          child: _buildBookSpine(book, index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
             decoration: BoxDecoration(
               border: Border.all(color: Colors.black, width: 2),
               boxShadow: [_comicShadow],
               shape: BoxShape.circle,
             ),
            child: FloatingActionButton.small(
              heroTag: "scan",
              onPressed: _scanBarcode,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(Icons.qr_code_scanner, size: 24),
            ),
          ),
          const SizedBox(height: 16),
          Container(
             decoration: BoxDecoration(
               border: Border.all(color: Colors.black, width: 2),
               boxShadow: [_comicShadow],
               shape: BoxShape.circle,
             ),
            child: FloatingActionButton(
              heroTag: "add",
              onPressed: _addBookFromSearch,
              backgroundColor: const Color(0xFFFFD740),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 36),
            ),
          ),
        ],
      ),
    );
  }
}