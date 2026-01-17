import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @profile_info.
  ///
  /// In fr, this message translates to:
  /// **'Informations du profil'**
  String get profile_info;

  /// No description provided for @edit_profile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mes informations'**
  String get edit_profile;

  /// No description provided for @security.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get security;

  /// No description provided for @change_password.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get change_password;

  /// No description provided for @connected_devices.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get connected_devices;

  /// No description provided for @appearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get appearance;

  /// No description provided for @dark_mode.
  ///
  /// In fr, this message translates to:
  /// **'Mode sombre'**
  String get dark_mode;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @choose_language.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la langue'**
  String get choose_language;

  /// No description provided for @others.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get others;

  /// No description provided for @privacy_policy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de Confidentialité'**
  String get privacy_policy;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @delete_account.
  ///
  /// In fr, this message translates to:
  /// **'Désactivation / Suppression du compte'**
  String get delete_account;

  /// No description provided for @account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get account;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get logout;

  /// No description provided for @menu.
  ///
  /// In fr, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get home;

  /// No description provided for @friends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get friends;

  /// No description provided for @reels.
  ///
  /// In fr, this message translates to:
  /// **'Zua Reels'**
  String get reels;

  /// No description provided for @saved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrements'**
  String get saved;

  /// No description provided for @dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboard;

  /// No description provided for @verify.
  ///
  /// In fr, this message translates to:
  /// **'Vérification'**
  String get verify;

  /// No description provided for @help.
  ///
  /// In fr, this message translates to:
  /// **'Assistance'**
  String get help;

  /// No description provided for @support_center.
  ///
  /// In fr, this message translates to:
  /// **'Centre d’aide'**
  String get support_center;

  /// No description provided for @already_verified.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà le badge bleu'**
  String get already_verified;

  /// No description provided for @error_loading_menu.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement du menu'**
  String get error_loading_menu;

  /// No description provided for @login.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get login;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Adresse email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @forgot_password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgot_password;

  /// No description provided for @no_account.
  ///
  /// In fr, this message translates to:
  /// **'Pas de compte ? Créer un compte'**
  String get no_account;

  /// No description provided for @login_success.
  ///
  /// In fr, this message translates to:
  /// **'Connexion réussie'**
  String get login_success;

  /// No description provided for @light_mode.
  ///
  /// In fr, this message translates to:
  /// **'Mode clair'**
  String get light_mode;

  /// No description provided for @system_mode.
  ///
  /// In fr, this message translates to:
  /// **'Mode système'**
  String get system_mode;

  /// No description provided for @change_language.
  ///
  /// In fr, this message translates to:
  /// **'Changer la langue'**
  String get change_language;

  /// No description provided for @no_notifications.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification pour le moment'**
  String get no_notifications;

  /// No description provided for @error_loading_notifications.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les notifications.'**
  String get error_loading_notifications;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @notif_like.
  ///
  /// In fr, this message translates to:
  /// **'a aimé votre publication.'**
  String get notif_like;

  /// No description provided for @notif_comment.
  ///
  /// In fr, this message translates to:
  /// **'a commenté votre publication.'**
  String get notif_comment;

  /// No description provided for @notif_reply.
  ///
  /// In fr, this message translates to:
  /// **'a répondu à votre commentaire.'**
  String get notif_reply;

  /// No description provided for @notif_share.
  ///
  /// In fr, this message translates to:
  /// **'a partagé votre publication.'**
  String get notif_share;

  /// No description provided for @notif_share_received.
  ///
  /// In fr, this message translates to:
  /// **'vous a partagé une publication.'**
  String get notif_share_received;

  /// No description provided for @notif_save.
  ///
  /// In fr, this message translates to:
  /// **'a enregistré votre publication.'**
  String get notif_save;

  /// No description provided for @notif_follow.
  ///
  /// In fr, this message translates to:
  /// **'s’est abonné à votre compte.'**
  String get notif_follow;

  /// No description provided for @notif_badge_accept.
  ///
  /// In fr, this message translates to:
  /// **'Votre badge a été validé.'**
  String get notif_badge_accept;

  /// No description provided for @notif_badge_refuse.
  ///
  /// In fr, this message translates to:
  /// **'Votre demande de badge a été refusée.'**
  String get notif_badge_refuse;

  /// No description provided for @notif_badge_removed.
  ///
  /// In fr, this message translates to:
  /// **'Votre badge a été retiré.'**
  String get notif_badge_removed;

  /// No description provided for @notif_default.
  ///
  /// In fr, this message translates to:
  /// **'a interagi avec votre compte.'**
  String get notif_default;

  /// No description provided for @nav_home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get nav_home;

  /// No description provided for @nav_friends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get nav_friends;

  /// No description provided for @nav_profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get nav_profile;

  /// No description provided for @nav_notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifs'**
  String get nav_notifications;

  /// No description provided for @nav_menu.
  ///
  /// In fr, this message translates to:
  /// **'Menu'**
  String get nav_menu;

  /// No description provided for @friends_title.
  ///
  /// In fr, this message translates to:
  /// **'Ami(e)s'**
  String get friends_title;

  /// No description provided for @friends_search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get friends_search;

  /// No description provided for @friends_all.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get friends_all;

  /// No description provided for @friends_invites.
  ///
  /// In fr, this message translates to:
  /// **'Invitations'**
  String get friends_invites;

  /// No description provided for @friends_others.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get friends_others;

  /// No description provided for @friends_received_invitations.
  ///
  /// In fr, this message translates to:
  /// **'Invitations reçues'**
  String get friends_received_invitations;

  /// No description provided for @friends_other_users.
  ///
  /// In fr, this message translates to:
  /// **'Autres utilisateurs'**
  String get friends_other_users;

  /// No description provided for @friends_suggestions.
  ///
  /// In fr, this message translates to:
  /// **'Personnes que vous connaissez peut-être'**
  String get friends_suggestions;

  /// No description provided for @friends_all_members.
  ///
  /// In fr, this message translates to:
  /// **'Tous les membres'**
  String get friends_all_members;

  /// No description provided for @friends_follow.
  ///
  /// In fr, this message translates to:
  /// **'S’abonner'**
  String get friends_follow;

  /// No description provided for @friends_follow_back.
  ///
  /// In fr, this message translates to:
  /// **'S’abonner en retour'**
  String get friends_follow_back;

  /// No description provided for @friends_unfollow.
  ///
  /// In fr, this message translates to:
  /// **'Se désabonner'**
  String get friends_unfollow;

  /// No description provided for @friends_followers.
  ///
  /// In fr, this message translates to:
  /// **'abonnés'**
  String get friends_followers;

  /// No description provided for @friends_following.
  ///
  /// In fr, this message translates to:
  /// **'abonnements'**
  String get friends_following;

  /// No description provided for @friends_suggestion.
  ///
  /// In fr, this message translates to:
  /// **'Suggestion'**
  String get friends_suggestion;

  /// No description provided for @signup_create_account.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get signup_create_account;

  /// No description provided for @signup_create_button.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get signup_create_button;

  /// No description provided for @signup_verify_code.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier le code'**
  String get signup_verify_code;

  /// No description provided for @common_next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get common_next;

  /// No description provided for @signup_firstname.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get signup_firstname;

  /// No description provided for @signup_lastname.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get signup_lastname;

  /// No description provided for @error_email_required.
  ///
  /// In fr, this message translates to:
  /// **'Email obligatoire'**
  String get error_email_required;

  /// No description provided for @error_select_country.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un pays'**
  String get error_select_country;

  /// No description provided for @notification.
  ///
  /// In fr, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @notif_admin.
  ///
  /// In fr, this message translates to:
  /// **'Message officiel de ZuaChat'**
  String get notif_admin;

  /// No description provided for @notif_admin_label.
  ///
  /// In fr, this message translates to:
  /// **'ZuaChat'**
  String get notif_admin_label;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
