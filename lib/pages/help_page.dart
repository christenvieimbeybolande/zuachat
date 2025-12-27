import 'package:flutter/material.dart';
import '../api/help.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/zua_loader.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  bool _loading = true;
  bool _error = false;
  bool hasTicket = false;
  Map<String, dynamic>? ticket;
  List messages = [];
  Map<String, dynamic>? agent;
  final _msgCtrl = TextEditingController();
  final _titreCtrl = TextEditingController();
  final _firstMsgCtrl = TextEditingController();

  static const primary = Color.fromARGB(255, 255, 0, 0);
  static const bg = Color(0xFFF0F2F5);

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    setState(() => _loading = true);
    final res = await fetchHelpTicket();
    if (res['success'] == true) {
      setState(() {
        hasTicket = res['active_ticket'] == true;
        ticket = res['ticket'];
        messages = res['messages'] ?? [];
        agent = res['agent'];
        _error = false;
      });
    } else {
      setState(() => _error = true);
    }
    setState(() => _loading = false);
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    final msg = _msgCtrl.text.trim();
    _msgCtrl.clear();

    final res = await sendHelpMessage(ticket?['id'], msg);
    if (res['success'] == true) {
      _loadTicket();
    } else {
      _snack(res['message']);
    }
  }

  Future<void> _createTicket() async {
    final titre = _titreCtrl.text.trim();
    final msg = _firstMsgCtrl.text.trim();
    if (titre.isEmpty || msg.isEmpty)
      return _snack("Veuillez remplir tous les champs");

    final res = await createHelpTicket(titre, msg);
    if (res['success'] == true) {
      _snack("Ticket créé ");
      _titreCtrl.clear();
      _firstMsgCtrl.clear();
      _loadTicket();
    } else {
      _snack(res['message']);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: ZuaLoader(size: 100, looping: true)),
      );
    }

    if (_error) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: ElevatedButton(
            onPressed: _loadTicket,
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: const Text("Réessayer"),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(" Assistance"),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: hasTicket ? _buildChat() : _buildNewTicketForm(),
      ),
    );
  }

  Widget _buildNewTicketForm() {
    return ListView(
      children: [
        const Text(
          "Créer un nouveau ticket d’assistance",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titreCtrl,
          decoration: const InputDecoration(
            labelText: "Titre du ticket",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _firstMsgCtrl,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: "Décrivez votre problème...",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _createTicket,
          style: ElevatedButton.styleFrom(backgroundColor: primary),
          child: const Text("Créer le ticket"),
        ),
      ],
    );
  }

  Widget _buildChat() {
    final statut = ticket?['statut'];
    return Column(
      children: [
        if (agent != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              "👩‍💼 Agent : ${agent!['fullname'] ?? 'En attente...'}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final m = messages[i];
              final isUser = m['sender_type'] == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isUser ? primary : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    m['message'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (statut == 'en_cours') _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: const InputDecoration(
                hintText: "Écrire un message...",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 5),
          ElevatedButton(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: const Text("Envoyer"),
          )
        ],
      ),
    );
  }
}
