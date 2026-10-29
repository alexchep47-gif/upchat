import 'dart:html' as html;

import 'package:flutter/material.dart';

void setWebThemeColor(Color color) {
  final argb = color.value.toRadixString(16).padLeft(8, '0');
  final cssColor = '#${argb.substring(2).toUpperCase()}';

  for (final element
      in html.document.querySelectorAll('meta[name="theme-color"]')) {
    if (element is html.MetaElement) element.content = cssColor;
  }

  html.document.documentElement?.style.backgroundColor = cssColor;
  html.document.body?.style.backgroundColor = cssColor;
}
