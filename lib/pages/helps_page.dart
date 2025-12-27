import 'package:flutter/material.dart';

class HelpsPage extends StatelessWidget {
  const HelpsPage({super.key});

  static const Color primary = Color.fromARGB(255, 255, 0, 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF18191A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Centre d’aide ZuaChat"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _title("Bienvenue sur le centre d’aide"),
            _para(
              "Cette page a pour objectif de vous aider à comprendre et utiliser "
              "correctement l’application ZuaChat. Vous y trouverez des réponses "
              "aux questions les plus fréquentes concernant votre compte, "
              "la sécurité, les publications, la confidentialité et vos droits.",
            ),

            // =====================================================
            _title("1. Création de compte"),
            _para(
              "Pour utiliser ZuaChat, vous devez créer un compte utilisateur "
              "en fournissant des informations exactes et à jour.",
            ),
            _bulletList([
              "Un compte peut être personnel ou professionnel.",
              "L’adresse e-mail doit être valide et vérifiée.",
              "Un seul compte est autorisé par utilisateur.",
              "Vous êtes responsable de la confidentialité de vos identifiants.",
            ]),

            // =====================================================
            _title("2. Connexion et sécurité"),
            _para(
              "La sécurité de votre compte est une priorité pour ZuaChat.",
            ),
            _bulletList([
              "Les mots de passe sont chiffrés et jamais stockés en clair.",
              "Les connexions suspectes peuvent être bloquées.",
              "Vous pouvez changer votre mot de passe à tout moment.",
              "Les sessions actives peuvent être révoquées depuis les paramètres.",
            ]),

            // =====================================================
            _title("3. Publication de contenu"),
            _para(
              "ZuaChat permet de publier du texte, des images et des vidéos "
              "(reels). Tout contenu doit respecter les règles de la plateforme.",
            ),
            _bulletList([
              "Les contenus pornographiques ou violents sont interdits.",
              "Les images et vidéos sont analysées automatiquement avant publication.",
              "Les contenus signalés peuvent être supprimés sans préavis.",
              "Les récidives peuvent entraîner des sanctions.",
            ]),

            // =====================================================
            _title("4. Modération et signalement"),
            _para(
              "ZuaChat utilise une combinaison de modération automatique "
              "et humaine pour garantir un environnement sain.",
            ),
            _bulletList([
              "Vous pouvez signaler un contenu ou un utilisateur.",
              "Les signalements sont analysés par notre système.",
              "Un contenu contraire aux règles est supprimé.",
              "Les comptes abusifs peuvent être suspendus ou supprimés.",
            ]),

            // =====================================================
            _title("5. Messages et interactions"),
            _para(
              "Les messages privés et interactions doivent rester respectueux.",
            ),
            _bulletList([
              "Le harcèlement et les menaces sont interdits.",
              "Les messages peuvent être bloqués ou signalés.",
              "Vous pouvez bloquer un utilisateur à tout moment.",
            ]),

            // =====================================================
            _title("6. Confidentialité et données personnelles"),
            _para(
              "ZuaChat respecte votre vie privée et protège vos données.",
            ),
            _bulletList([
              "Vos données ne sont jamais revendues.",
              "Certaines données sont nécessaires au fonctionnement du service.",
              "Vous pouvez demander l’accès ou la suppression de vos données.",
              "Les règles complètes sont disponibles dans la Politique de confidentialité.",
            ]),

            // =====================================================
            _title("7. Suppression de compte"),
            _para(
              "Vous pouvez demander la suppression de votre compte à tout moment.",
            ),
            _bulletList([
              "La suppression peut être immédiate ou différée.",
              "Certaines données peuvent être conservées pour des raisons légales.",
              "Une suppression confirmée est irréversible.",
            ]),

            // =====================================================
            _title("8. Problèmes techniques"),
            _para(
              "En cas de problème technique, assurez-vous d’abord que :",
            ),
            _bulletList([
              "Votre application est à jour.",
              "Votre connexion internet fonctionne.",
              "Vous utilisez une version officielle de ZuaChat.",
            ]),

            // =====================================================
            _title("9. Respect des règles"),
            _para(
              "L’utilisation de ZuaChat implique le respect des règles de la communauté.",
            ),
            _bulletList([
              "Tout abus peut entraîner une suspension.",
              "ZuaChat se réserve le droit de modifier ses règles.",
              "Les décisions de modération sont définitives.",
            ]),

            // =====================================================
            _title("10. Contact et assistance"),
            _para(
              "Si vous avez besoin d’aide supplémentaire, vous pouvez contacter "
              "l’équipe ZuaChat.",
            ),
            _bulletList([
              "Email : contact@cimstudiodev.com",
              "Support technique via l’application.",
              "Demandes liées aux données personnelles.",
            ]),

            // =====================================================
            _title("11. Mise à jour de la page d’aide"),
            _para(
              "Cette page peut être mise à jour à tout moment afin de refléter "
              "les évolutions de l’application et des règles.",
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // =========================
  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
    );
  }

  Widget _para(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: const TextStyle(fontSize: 15, height: 1.45),
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((e) {
        return Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("•  "),
              Expanded(
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
