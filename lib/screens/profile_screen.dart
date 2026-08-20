import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user.name),
            subtitle: Text(user.email),
          ),
          const Divider(),
          ListTile(
            title: const Text('Rôle'),
            subtitle: Text(user.role),
          ),
          ListTile(
            title: const Text('Statut'),
            subtitle: Text(user.status),
          ),
          ListTile(
            title: const Text('Peut gérer les sondages'),
            subtitle: Text(user.canManageSurveys ? 'Oui' : 'Non'),
          ),
          if (user.employee != null)
            ListTile(
              title: const Text('Poste'),
              subtitle: Text(user.employee!.position ?? '-'),
            ),
          ListTile(
            title: const Text('API'),
            subtitle: Text(ApiConfig.baseUrl),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}
