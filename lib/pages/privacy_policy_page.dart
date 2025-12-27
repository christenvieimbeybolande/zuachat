import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const primary = Color.fromARGB(255, 255, 0, 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF18191A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Politique de confidentialité"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _title("Introduction"),
            _para(
              "La présente politique de confidentialité explique de manière claire et transparente "
              "comment ZuaChat collecte, utilise, conserve et protège les données personnelles de ses utilisateurs. "
              "ZuaChat est une application de réseau social développée et exploitée par CimStudioDev.",
            ),
            _para(
              "En utilisant ZuaChat, vous acceptez les pratiques décrites dans cette politique. "
              "Si vous n’êtes pas d’accord avec ces conditions, veuillez ne pas utiliser l’application.",
            ),

            _title("1. Champ d’application"),
            _para(
              "Cette politique s’applique à l’ensemble des services proposés par ZuaChat, "
              "y compris l’application mobile, les services web, les API et toute fonctionnalité associée.",
            ),

            _title("2. Données personnelles collectées"),
            _para("Nous collectons plusieurs catégories de données :"),
            _bulletList([
              "Informations d’identification : nom, prénom, postnom, nom d’utilisateur.",
              "Informations de contact : adresse e-mail, numéro de téléphone.",
              "Informations démographiques : sexe, date de naissance, pays.",
              "Contenu utilisateur : photos, vidéos, publications, commentaires, messages.",
              "Informations techniques : adresse IP, type d’appareil, système d’exploitation, navigateur.",
              "Données de connexion : dates, heures, sessions, jetons de sécurité.",
            ]),

            _title("3. Données sensibles"),
            _para(
              "ZuaChat ne demande pas volontairement de données sensibles telles que les opinions politiques, "
              "les croyances religieuses, l’origine ethnique ou les données médicales.",
            ),

            _title("4. Finalités du traitement"),
            _para("Les données collectées sont utilisées pour :"),
            _bulletList([
              "Créer et gérer les comptes utilisateurs.",
              "Permettre la communication entre utilisateurs.",
              "Afficher le contenu publié par les utilisateurs.",
              "Assurer la sécurité des comptes et prévenir les abus.",
              "Améliorer les performances et l’expérience utilisateur.",
              "Respecter les obligations légales et réglementaires.",
            ]),

            _title("5. Base légale du traitement"),
            _bulletList([
              "Votre consentement lors de l’inscription.",
              "L’exécution du contrat entre l’utilisateur et ZuaChat.",
              "Le respect des obligations légales.",
              "L’intérêt légitime lié à la sécurité et à l’amélioration du service.",
            ]),

            _title("6. Partage des données"),
            _para(
              "ZuaChat ne vend jamais les données personnelles. "
              "Les données peuvent être partagées uniquement avec :",
            ),
            _bulletList([
              "Des prestataires techniques (hébergement, stockage, sécurité).",
              "Des services de modération automatisée pour lutter contre les contenus interdits.",
              "Les autorités compétentes lorsque la loi l’exige.",
            ]),

            _title("7. Transfert international"),
            _para(
              "Certaines données peuvent être traitées ou stockées sur des serveurs situés en dehors de votre pays. "
              "Dans ce cas, ZuaChat s’assure que des garanties appropriées sont en place.",
            ),

            _title("8. Sécurité des données"),
            _para(
              "ZuaChat met en œuvre des mesures de sécurité techniques et organisationnelles "
              "afin de protéger les données contre l’accès non autorisé, la perte, l’altération ou la divulgation.",
            ),
            _bulletList([
              "Chiffrement des communications.",
              "Authentification sécurisée.",
              "Contrôles d’accès stricts.",
              "Surveillance et journalisation des accès.",
            ]),

            _title("9. Conservation des données"),
            _para(
              "Les données sont conservées aussi longtemps que nécessaire pour fournir les services "
              "ou pour satisfaire aux obligations légales. "
              "Les comptes supprimés entraînent la suppression progressive des données associées.",
            ),

            _title("10. Vos droits"),
            _para("Conformément aux lois applicables, vous disposez des droits suivants :"),
            _bulletList([
              "Droit d’accès à vos données personnelles.",
              "Droit de rectification des informations incorrectes.",
              "Droit à l’effacement (droit à l’oubli).",
              "Droit à la limitation du traitement.",
              "Droit d’opposition au traitement.",
              "Droit à la portabilité des données.",
            ]),

            _title("11. Suppression de compte"),
            _para(
              "Vous pouvez demander la suppression de votre compte à tout moment depuis l’application "
              "ou en contactant le support. Certaines données peuvent être conservées pour des raisons légales.",
            ),

            _title("12. Cookies et technologies similaires"),
            _para(
              "ZuaChat utilise des cookies et technologies similaires pour sécuriser les sessions, "
              "analyser l’utilisation du service et améliorer les performances.",
            ),

            _title("13. Protection des mineurs"),
            _para(
              "ZuaChat n’est pas destiné aux enfants de moins de 13 ans. "
              "Aucune donnée n’est collectée intentionnellement auprès des mineurs.",
            ),

            _title("14. Modération du contenu"),
            _para(
              "ZuaChat utilise des systèmes de modération automatisés et humains "
              "pour détecter et supprimer les contenus interdits ou illégaux.",
            ),

            _title("15. Modifications de la politique"),
            _para(
              "Cette politique peut être mise à jour à tout moment. "
              "Les utilisateurs seront informés en cas de modification importante.",
            ),

            _title("16. Responsable du traitement"),
            _para(
              "Le responsable du traitement des données est CimStudioDev, "
              "éditeur et exploitant de l’application ZuaChat.",
            ),

            _title("17. Contact"),
            _para(
              "Pour toute question relative à la confidentialité ou à vos données personnelles, "
              "vous pouvez nous contacter à l’adresse suivante : contact@cimstudiodev.com",
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
