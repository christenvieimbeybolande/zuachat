import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AlbumCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onMenu;

  const AlbumCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.count,
    required this.onTap,
    this.onMenu,
  });

  static const String defaultCover =
      "https://zuachat.com/assets/dossiervide.jpg";

  static const Color primaryRed = Color(0xFFFF0000);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildImage()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  if (onMenu != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert,
                          size: 20, color: primaryRed),
                      onPressed: onMenu,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 10),
              child: Text(
                "$count photo${count > 1 ? 's' : ''}",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final realUrl = imageUrl.isEmpty ? defaultCover : imageUrl;

    return CachedNetworkImage(
      imageUrl: realUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[300]),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }
}
