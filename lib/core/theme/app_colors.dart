import 'package:flutter/material.dart';

/// Palette de couleurs UpChat (style WhatsApp moderne)
class AppColors {
  // Principales
  static const Color primary = Color(0xFF128C7E);
  static const Color accent = Color(0xFF25D366);
  static const Color darkPrimary = Color(0xFF075E54);

  // Bulles de chat
  static const Color bubbleMe = Color(0xFFDCF8C6);       // vert clair (messages envoyés)
  static const Color bubbleOther = Color(0xFFFFFFFF);   // blanc (messages reçus)
  static const Color bubbleMeDark = Color(0xFF005C4B);
  static const Color bubbleOtherDark = Color(0xFF1F2C34);

  // Fonds
  static const Color backgroundLight = Color(0xFFEFE7DE); // fond chat clair
  static const Color backgroundDark = Color(0xFF0B141A);  // OLED noir
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F2C34);

  // Texte
  static const Color textPrimaryLight = Color(0xFF111B21);
  static const Color textSecondaryLight = Color(0xFF667781);
  static const Color textPrimaryDark = Color(0xFFE9EDEF);
  static const Color textSecondaryDark = Color(0xFF8696A0);

  // Statuts
  static const Color online = Color(0xFF25D366);
  static const Color offline = Color(0xFF8696A0);
  static const Color unread = Color(0xFF25D366);

  // Divers
  static const Color dividerLight = Color(0xFFE9EDEF);
  static const Color dividerDark = Color(0xFF2A3942);
  static const Color error = Color(0xFFEA0038);
  static const Color warning = Color(0xFFF0B429);
}
