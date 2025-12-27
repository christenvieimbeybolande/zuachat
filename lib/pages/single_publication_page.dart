import 'package:flutter/material.dart';

import '../api/fetch_publication_single.dart';
import '../api/client.dart';
import '../widgets/publication_card.dart';

class SinglePublicationPage extends StatelessWidget {
  final int publicationId;

  const SinglePublicationPage({
    super.key,
    required this.publicationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF0000),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        title: const Text("Publication"),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchSinglePublication(publicationId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data == null) {
            return const Center(child: Text("Publication introuvable"));
          }

          return ListView(
            padding: const EdgeInsets.all(10),
            children: [
              PublicationCard(
                publication: snap.data!,
                authedDio: ApiClient.authed,
                showMenu: true,
              ),
            ],
          );
        },
      ),
    );
  }
}
