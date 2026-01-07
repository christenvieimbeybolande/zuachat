// lib/utils/feed_ranker.dart
import 'dart:math';

class FeedRanker {
  static final Random _r = Random();

  static List<Map<String, dynamic>> rank(List<Map<String, dynamic>> pubs) {
    final now = DateTime.now();

    final scored = pubs.map((p) {
      // -------------------------
      // ENGAGEMENT
      // -------------------------
      int likes = int.tryParse("${p['likes'] ?? 0}") ?? 0;
      int comments = int.tryParse("${p['comments'] ?? 0}") ?? 0;
      int shares = int.tryParse("${p['shares'] ?? 0}") ?? 0;

      double engagement = (likes * 1.0) + (comments * 2.0) + (shares * 3.0);

      // -------------------------
      // FRAÎCHEUR / ÂGE
      // -------------------------
      double freshnessBoost = 0.0;
      double agePenalty = 0.0;

      if (p['created_at'] != null) {
        final t = DateTime.tryParse(p['created_at']);
        if (t != null) {
          final hours = now.difference(t).inHours;

          // 🔥 Boost fort 48h
          if (hours <= 48) {
            freshnessBoost = (50 - hours).toDouble();
          }

          // ❌ Pénalité après 3 jours
          if (hours > 72) {
            agePenalty = min((hours - 72) * 0.15, 40.0);
          }
        }
      }

      // -------------------------
      // TYPE BONUS
      // -------------------------
      String type = "${p['type_publication']}".toLowerCase();
      double typeBonus = (type == "profil" || type == "cover") ? 5.0 : 0.0;

      // -------------------------
      // RANDOM LÉGER
      // -------------------------
      double random = _r.nextDouble() * 3.0;

      // -------------------------
      // SCORE FINAL
      // -------------------------
      double score =
          engagement + freshnessBoost + typeBonus + random - agePenalty;

      return {
        "score": score,
        "pub": p,
      };
    }).toList();

    scored.sort(
      (a, b) => (b["score"] as double).compareTo(a["score"] as double),
    );

    return scored.map((e) => e["pub"] as Map<String, dynamic>).toList();
  }
}
