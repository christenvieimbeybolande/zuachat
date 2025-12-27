import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/following.dart';
import '../api/client.dart';
import '../pages/user_profile.dart';

class FollowingPage extends StatefulWidget {
  final int userId;

  const FollowingPage({super.key, required this.userId});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  List<Map<String, dynamic>> following = [];
  bool loading = true;

  int? currentUserId;
  final TextEditingController searchCtrl = TextEditingController();
  static const primary = Color.fromARGB(255, 255, 0, 0);

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = int.tryParse(prefs.getString('user_id') ?? '0');
    await _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    setState(() => loading = true);

    final result = await fetchFollowing(widget.userId);
    if (result["ok"] == true) {
      setState(() => following = result["following"]);
    }

    setState(() => loading = false);
  }

  Future<void> _toggleFollow(int id) async {
    final index =
        following.indexWhere((u) => u['id'].toString() == id.toString());
    if (index == -1) return;

    final user = following[index];
    final bool wasFollowing = user['is_following'] == true;

    setState(() {
      user['is_following'] = !wasFollowing;
      if (!wasFollowing) user['is_followed_by_me'] = false;
    });

    final dio = await ApiClient.authed();
    await dio.post('/follow_user.php', data: {'target_id': id});

    await _loadFollowing();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = searchCtrl.text.isEmpty
        ? following
        : following.where((u) {
            final name =
                "${u['prenom'] ?? ''} ${u['nom'] ?? ''} ${u['postnom'] ?? ''} ${u['username'] ?? ''}"
                    .toLowerCase();
            return name.contains(searchCtrl.text.toLowerCase());
          }).toList();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text("Abonnements",
              style: TextStyle(
                  color: primary, fontWeight: FontWeight.bold, fontSize: 20)),
          iconTheme: const IconThemeData(color: primary),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: primary))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Rechercher...",
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadFollowing,
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: filtered.map(_buildUserCard).toList(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final int id = int.parse(u['id'].toString());
    final bool isFollowing = u['is_following'] == true;
    final bool isFollowedByMe = u['is_followed_by_me'] == true;
    final bool isMe = id == currentUserId;

    String btn = "S’abonner";
    if (isFollowing)
      btn = "Se désabonner";
    else if (isFollowedByMe) btn = "S’abonner en retour";

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfilePage(userId: id)),
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: CachedNetworkImageProvider(
            u['photo'] ?? "https://zuachat.com/assets/default-avatar.png",
          ),
        ),
        title: Text(
          "${u['prenom'] ?? ''} ${u['nom'] ?? ''} ${u['postnom'] ?? ''}".trim(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("@${u['username']}"),
        trailing: isMe
            ? const SizedBox()
            : ElevatedButton(
                onPressed: () => _toggleFollow(id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey : primary,
                  foregroundColor: isFollowing ? Colors.black : Colors.white,
                ),
                child: Text(btn),
              ),
      ),
    );
  }
}
