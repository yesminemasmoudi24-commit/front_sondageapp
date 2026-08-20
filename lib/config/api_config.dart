import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;

/// Configuration API Laravel (backend_projetsondage).
///
/// Backend : `php artisan serve` → Base URL `http://127.0.0.1:8000/api`
///
/// - Desktop / iOS simulateur / Web : 127.0.0.1
/// - Émulateur Android : 10.0.2.2 (alias de la machine hôte)
/// - Téléphone physique : remplace [lanHost] par l'IP de ton PC
class ApiConfig {
  ApiConfig._();

  /// IP locale du PC si tu testes sur un vrai téléphone (même Wi‑Fi).
  static const String? lanHost = null; // ex. '192.168.1.10'

  static String get host {
    if (lanHost != null && lanHost!.isNotEmpty) return lanHost!;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  static const int port = 8000;

  static String get baseUrl => 'http://$host:$port/api';
}
