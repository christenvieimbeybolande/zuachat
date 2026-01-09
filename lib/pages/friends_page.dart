import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../gen_l10n/app_localizations.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/verified_badge.dart';
import '../api/client.dart';
import '../api/friends.dart';
import '../pages/profile_page.dart';
import '../pages/user_profile.dart';
import '../pages/feed_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  static const primary = Color(0xFFFF0000);

  List<Map<String, dynamic>> invitations = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> suggestions = [];

  bool loading = true;
  int? currentUserId;

  int unreadNotifications = 0;
  int unreadMessages = 0;

  bool showSearch = false;
  String filter = "all";
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadCounters();
  }

  // ===================== UTIL =====================

  String getDisplayName(Map<String, dynamic> u) {
    final prenom = u['prenom'] ?? '';
    final nom = u['nom'] ?? '';
    final postnom = u['postnom'] ?? '';
    final username = u['username'] ?? '';
    final categorie = u['categorie'] ?? '';
    final type = u['type_compte'] ?? 'personnel';

    if (prenom.isNotEmpty || nom.isNotEmpty || postnom.isNotEmpty) {
      return "$prenom $nom $postnom".trim();
    }

    if (type == "professionnel") {
      return username.isNotEmpty ? username : categorie;
    }

    return username.isNotEmpty ? username : "Usuario";
  }

  Future<void> _loadCounters() async {
    try {
      final dio = await ApiClient.authed();
      final res = await dio.get('/home_feed.php');
      if (res.data['ok'] == true) {
        setState(() {
          unreadNotifications = res.data['unread_notifications'] ?? 0;
          unreadMessages = res.data['unread_messages'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = int.tryParse(prefs.getString('user_id') ?? "0");
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => loading = true);

    final res = await fetchFriendsData();
    if (res["ok"] == true) {
      invitations = List<Map<String, dynamic>>.from(res["invitations"]);
      users = List<Map<String, dynamic>>.from(res["users"]);
      suggestions = users
          .where((u) => u["is_following"] == false && u["badge_verified"] == 1)
          .take(5)
          .toList();
    }

    setState(() => loading = false);
  }

  Future<void> _follow(int userId) async {
    final dio = await ApiClient.authed();
    await dio.post('/follow_user.php', data: {'target_id': userId});
    _loadFriends();
  }

  Future<void> _unfollow(int userId) async {
    final dio = await ApiClient.authed();
    await dio.post('/follow_user.php', data: {'target_id': userId});
    _loadFriends();
  }

  void _openProfile(BuildContext context, int userId) {
    if (currentUserId == userId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)),
      );
    }
  }

  void _toggleSearch() => setState(() => showSearch = !showSearch);

  // ===================== UI =====================

  Widget _filterButton(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    final isSelected = filter == value;

    return GestureDetector(
      onTap: () => setState(() => filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final filtered = searchCtrl.text.trim().isEmpty
        ? users
        : users.where((u) {
            final name = getDisplayName(u).toLowerCase();
            final uname = (u['username'] ?? "").toLowerCase();
            final query = searchCtrl.text.toLowerCase();
            return name.contains(query) || uname.contains(query);
          }).toList();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FeedPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FeedPage()),
              );
            },
          ),
          title: Text(
            t.friends_title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: _toggleSearch,
            ),
          ],
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: 1,
          unreadNotifications: unreadNotifications,
          unreadMessages: unreadMessages,
        ),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(color: primary),
              )
            : Column(
                children: [
                  if (showSearch)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: t.friends_search,
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _filterButton(context, "all", t.friends_all),
                        _filterButton(context, "invites", t.friends_invites),
                        _filterButton(
                            context, "nonfollowers", t.friends_others),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: primary,
                      onRefresh: _loadFriends,
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: _buildFilteredContent(context, filtered, t),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ===================== LISTES =====================

  List<Widget> _buildFilteredContent(
    BuildContext context,
    List<Map<String, dynamic>> filtered,
    AppLocalizations t,
  ) {
    final theme = Theme.of(context);
    List<Widget> list = [];

    if (filter == "invites") {
      list.add(Text(t.friends_received_invitations,
          style: theme.textTheme.titleSmall));
      list.addAll(
          invitations.map((u) => _buildUserCard(context, u, t, invite: true)));
      return list;
    }

    if (filter == "nonfollowers") {
      final others = filtered.where((u) => u["is_followed_by_me"] == false);
      list.add(Text(t.friends_other_users, style: theme.textTheme.titleSmall));
      list.addAll(others.map((u) => _buildUserCard(context, u, t)));
      return list;
    }

    if (suggestions.isNotEmpty) {
      list.add(Text(t.friends_suggestions, style: theme.textTheme.titleSmall));
      list.addAll(suggestions.map((u) => _buildSuggestionCard(context, u, t)));
      list.add(const Divider());
    }

    if (invitations.isNotEmpty) {
      list.add(Text(t.friends_received_invitations,
          style: theme.textTheme.titleSmall));
      list.addAll(
          invitations.map((u) => _buildUserCard(context, u, t, invite: true)));
      list.add(const Divider());
    }

    list.add(Text(t.friends_all_members, style: theme.textTheme.titleSmall));
    list.addAll(filtered.map((u) => _buildUserCard(context, u, t)));

    return list;
  }

  // ===================== CARDS =====================

  Widget _buildUserCard(
    BuildContext context,
    Map<String, dynamic> u,
    AppLocalizations t, {
    bool invite = false,
  }) {
    final theme = Theme.of(context);

    final verified = u["badge_verified"] == 1;
    final isFollowing = u["is_following"] == true;
    final isFollowedByMe = u["is_followed_by_me"] == true;
    final userId = int.parse(u["id"].toString());

    String buttonText = t.friends_follow;
    if (invite || isFollowedByMe) buttonText = t.friends_follow_back;
    if (isFollowing) buttonText = t.friends_unfollow;

    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openProfile(context, userId),
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: CachedNetworkImageProvider(
            u["photo"] ?? "https://zuachat.com/assets/default-avatar.png",
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: AutoSizeText(
                getDisplayName(u),
                maxLines: 1, // 🔥 TOUJOURS 1 ligne
                minFontSize: 12, // 🔥 taille min
                maxFontSize: 16, // 🔥 taille max
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (verified) VerifiedBadge.mini(isVerified: true),
          ],
        ),
        subtitle: Text(
          "${u['followers_count']} ${t.friends_followers} · "
          "${u['following_count']} ${t.friends_following}",
          style: theme.textTheme.bodySmall,
        ),
        trailing: ElevatedButton(
          onPressed: () => isFollowing ? _unfollow(userId) : _follow(userId),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? theme.dividerColor : primary,
            foregroundColor:
                isFollowing ? theme.textTheme.bodyMedium?.color : Colors.white,
          ),
          child: Text(buttonText),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(
    BuildContext context,
    Map<String, dynamic> u,
    AppLocalizations t,
  ) {
    final verified = u["badge_verified"] == 1;
    final userId = int.parse(u["id"].toString());

    return ListTile(
      onTap: () => _openProfile(context, userId),
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(
          u["photo"] ??
              "https://zuachat.istmbosobe.com/assets/default-avatar.png",
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: AutoSizeText(
              getDisplayName(u),
              maxLines: 1,
              minFontSize: 12,
              maxFontSize: 16,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (verified) VerifiedBadge.mini(isVerified: true),
        ],
      ),
      subtitle: Text(t.friends_suggestion),
    );
  }
}
