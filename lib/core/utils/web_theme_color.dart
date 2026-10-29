import 'package:flutter/material.dart';

import 'web_theme_color_stub.dart'
    if (dart.library.html) 'web_theme_color_web.dart' as platform;

/// Met à jour la couleur d’interface du navigateur sur le Web ; sans effet natif.
void setWebThemeColor(Color color) => platform.setWebThemeColor(color);
