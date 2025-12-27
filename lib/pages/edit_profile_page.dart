import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../api/fetch_profile.dart';
import '../api/update_profile.dart';
import '../widgets/editable_tile.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const primary = Color.fromARGB(255, 255, 0, 0);

  bool _loading = true;

  // Controllers
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _postnomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  // Lists
  List<String> _countries = [];
  List<String> _categories = [];

  // Values
  String? _selectedCountry;
  String? _selectedCategory;
  String? _typeCompte;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _postnomCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // INIT
  // =====================================================
  Future<void> _init() async {
    await _loadLists();
    await _loadProfile();
    setState(() => _loading = false);
  }

  Future<void> _loadLists() async {
    final paysRaw = await rootBundle.loadString('assets/pays.json');
    final catRaw = await rootBundle.loadString('assets/categories.json');

    _countries = List<String>.from(jsonDecode(paysRaw));
    _categories = List<String>.from(jsonDecode(catRaw));
  }

  Future<void> _loadProfile() async {
    final res = await fetchProfile();
    final user = res['data']['user'];

    _typeCompte = user['type_compte'];

    _nomCtrl.text = user['nom'] ?? '';
    _prenomCtrl.text = user['prenom'] ?? '';
    _postnomCtrl.text = user['postnom'] ?? '';
    _telCtrl.text = user['telephone'] ?? '';

    _selectedCountry = user['pays'];
    _selectedCategory = user['categorie'];
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(
          'Modifier le profil',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // NOM (TOUS LES COMPTES)
          // =========================
          EditableTile(
            label: 'Nom',
            display: Text(_nomCtrl.text),
            editor: TextField(
              controller: _nomCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            onSave: () async {
              await updateProfile(nom: _nomCtrl.text.trim());
            },
          ),

          // =========================
          // PRENOM / POSTNOM (PERSONNEL)
          // =========================
          if (_typeCompte == 'personnel') ...[
            EditableTile(
              label: 'Prénom',
              display: Text(_prenomCtrl.text),
              editor: TextField(
                controller: _prenomCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              onSave: () async {
                await updateProfile(prenom: _prenomCtrl.text.trim());
              },
            ),
            EditableTile(
              label: 'Postnom',
              display: Text(
                _postnomCtrl.text.isEmpty ? 'Non renseigné' : _postnomCtrl.text,
              ),
              editor: TextField(
                controller: _postnomCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              onSave: () async {
                await updateProfile(postnom: _postnomCtrl.text.trim());
              },
            ),
          ],

          // =========================
          // TELEPHONE
          // =========================
          EditableTile(
            label: 'Téléphone',
            display: Text(
              _telCtrl.text.isEmpty ? 'Non renseigné' : _telCtrl.text,
            ),
            editor: TextField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            onSave: () async {
              await updateProfile(telephone: _telCtrl.text.trim());
            },
          ),

          // =========================
          // PAYS
          // =========================
          EditableTile(
            label: 'Pays',
            display: Text(_selectedCountry ?? 'Non renseigné'),
            editor: DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _countries
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _selectedCountry = v,
            ),
            onSave: () async {
              await updateProfile(pays: _selectedCountry);
            },
          ),

          // =========================
          // CATEGORIE (PERSONNEL + PRO)
          // =========================
          EditableTile(
            label: 'Catégorie',
            display: Text(
              _selectedCategory?.isNotEmpty == true
                  ? _selectedCategory!
                  : 'Non renseignée',
            ),
            editor: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _selectedCategory = v,
            ),
            onSave: () async {
              await updateProfile(categorie: _selectedCategory);
            },
          ),
        ],
      ),
    );
  }
}
