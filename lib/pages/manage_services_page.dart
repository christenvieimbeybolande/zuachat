import 'package:flutter/material.dart';
import '../api/services_api.dart';
import '../widgets/zua_loader.dart';

class ManageServicesPage extends StatefulWidget {
  const ManageServicesPage({super.key});

  @override
  State<ManageServicesPage> createState() => _ManageServicesPageState();
}

class _ManageServicesPageState extends State<ManageServicesPage> {
  bool _loading = true;
  bool _zuadeviEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final services = await ServicesApi.fetchServices();
      final zuadevi = services.firstWhere(
        (s) => s['service_code'] == 'zuadevi',
        orElse: () => {'enabled': 0},
      );

      setState(() {
        _zuadeviEnabled = zuadevi['enabled'] == 1;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleZuadevi(bool value) async {
    setState(() => _loading = true);

    if (value) {
      await ServicesApi.activate('zuadevi');
    } else {
      await ServicesApi.deactivate('zuadevi');
    }

    await _loadServices();
  }

  Future<void> _resetZuadevi() async {
    setState(() => _loading = true);
    await ServicesApi.reset('zuadevi');
    await _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes services'),
      ),
      body: _loading
          ? const Center(child: ZuaLoader(size: 80))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ZuaDevi',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Service de quiz et défis éducatifs.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: _zuadeviEnabled,
                          onChanged: _toggleZuadevi,
                          title: const Text('Accès activé'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title:
                              const Text('Réinitialiser mes données ZuaDevi'),
                          onTap: _resetZuadevi,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
