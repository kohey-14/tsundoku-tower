import 'dart:convert';
import 'package:flutter/material.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String imageUrl;
  final Color? spineColor;
  final DateTime addedDate;
  final int pageCount;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.imageUrl,
    this.spineColor,
    required this.addedDate,
    required this.pageCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'imageUrl': imageUrl,
      'spineColor': spineColor?.value,
      'addedDate': addedDate.toIso8601String(),
      'pageCount': pageCount,
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      imageUrl: json['imageUrl'],
      spineColor: json['spineColor'] != null ? Color(json['spineColor']) : null,
      addedDate: DateTime.parse(json['addedDate']),
      pageCount: json['pageCount'] ?? 300,
    );
  }
}