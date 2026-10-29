import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

void setWebThemeColor(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  final cssColor = '#${argb.substring(2).toUpperCase()}';

  final themeColors = web.document.querySelectorAll('meta[name="theme-color"]');
  for (var i = 0; i < themeColors.length; i++) {
    final element = themeColors.item(i);
    if (element is web.HTMLMetaElement) element.content = cssColor;
  }

  final root = web.document.documentElement;
  if (root is web.HTMLElement) root.style.backgroundColor = cssColor;
  web.document.body?.style.backgroundColor = cssColor;
}
