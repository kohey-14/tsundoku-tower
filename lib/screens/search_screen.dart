import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/book_service.dart';
import '../models/book.dart';
import 'scan_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _isbnController = TextEditingController();
  final BookService _bookService = BookService();
  Book? _foundBook;
  bool _isLoading = false;

  void _searchBook() async {
    if (_isbnController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final book = await _bookService.fetchBookByIsbn(_isbnController.text);
    setState(() {
      _foundBook = book;
      _isLoading = false;
    });
  }

  void _addBook() {
    if (_foundBook != null) {
      Navigator.pop(context, _foundBook);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本を追加')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _searchBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC0392B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF222222), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('装填（検索）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF222222), width: 2),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [BoxShadow(color: Color(0xFF222222), offset: Offset(2, 2))],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 28, color: Color(0xFFC0392B)),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScanScreen()),
                      );
                      if (result != null && result is String) {
                        setState(() { _isbnController.text = result; });
                        _searchBook();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _isbnController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'ISBNコード',
                hintText: '例: 9784...',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF222222), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFC0392B), width: 3),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoading) const CircularProgressIndicator(),
            if (_foundBook != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF222222), width: 2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Color(0xFF222222), offset: Offset(4, 4))],
                ),
                child: Column(
                  children: [
                    if (_foundBook!.imageUrl.isNotEmpty)
                      Image.network(_foundBook!.imageUrl, height: 150),
                    const SizedBox(height: 10),
                    Text(_foundBook!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                    Text(_foundBook!.author),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF222222),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('この本を積む', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}