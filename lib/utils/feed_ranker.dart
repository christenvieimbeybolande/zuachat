// lib/utils/feed_ranker.dart
import 'dart:math';

class FeedRanker {
  static final Random _r = Random();

  /// ⚡ Classe et mélange les publications façon Facebook
  static List<Map<String, dynamic>> rank(List<Map<String, dynamic>> pubs) {
    final scored = pubs.map((p) {
      int likes = int.tryParse("${p['likes'] ?? 0}") ?? 0;
      int comments = int.tryParse("${p['comments'] ?? 0}") ?? 0;
      int shares = int.tryParse("${p['shares'] ?? 0}") ?? 0;

      // 🔥 Popularité
      double popularity = likes * 1 + comments * 2 + shares * 3;

      // 🔥 Nouveauté
      double freshness = 0;
      if (p['created_at'] != null) {
        DateTime? t = DateTime.tryParse(p['created_at']);
        if (t != null) {
          final hours = DateTime.now().difference(t).inHours;
          freshness = 1 / (1 + hours); // plus récent = plus élevé
        }
      }

      // 🔥 Boost si c'est profil ou cover
      String type = "${p['type_publication']}".toLowerCase();
      double typeBonus = (type == "profil" || type == "cover") ? 10 : 0;

      // 🔥 Légère randomisation pour éviter classement fixe
      double randomFactor = _r.nextDouble() * 5;

      // SCORE FINAL
      double score = popularity + (freshness * 20) + typeBonus + randomFactor;

      return {"score": score, "pub": p};
    }).toList();

    // Trier du meilleur score au pire
    scored
        .sort((a, b) => (b["score"] as double).compareTo(a["score"] as double));

    // Retourner seulement les publications triées
    return scored.map((e) => e["pub"] as Map<String, dynamic>).toList();
  }
}
