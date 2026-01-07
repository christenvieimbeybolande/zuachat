// lib/utils/feed_ranker.dart
import 'dart:math';

class FeedRanker {
  static final Random _r = Random();

  /// 🎯 Mélange léger sans casser l'ordre serveur
  static List<Map<String, dynamic>> rank(List<Map<String, dynamic>> pubs) {
    final now = DateTime.now();

    return pubs.map((p) {
      double boost = 0;

      // 🔥 Boost engagement
      int likes = p['likes'] ?? 0;
      int comments = p['comments'] ?? 0;
      int shares = p['shares'] ?? 0;
      boost += (likes * 0.3) + (comments * 0.6) + (shares * 1);

      // 🔥 Boost récence (léger)
      if (p['created_at'] != null) {
        final t = DateTime.tryParse(p['created_at']);
        if (t != null) {
          final hours = now.difference(t).inHours;
          boost += max(0, 10 - hours); // 10h max
        }
      }

      // 🔥 Petit hasard (très faible)
      boost += _r.nextDouble() * 2;

      return {
        'boost': boost,
        'pub': p,
      };
    }).toList()
      ..sort((a, b) => (b['boost'] as double).compareTo(a['boost'] as double))
      ..map((e) => e['pub']).toList();
  }
}
