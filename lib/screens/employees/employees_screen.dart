import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/employee_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  Future<List<EmployeeModel>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<EmployeeModel>> _load() =>
      EmployeeService(context.read<AuthProvider>().api).list();

  Future<void> _create() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final position = TextEditingController();
    String role = 'employee';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvel employé'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe (≥8)'),
              ),
              TextField(
                controller: position,
                decoration: const InputDecoration(labelText: 'Poste'),
              ),
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('employee')),
                  DropdownMenuItem(value: 'delegated_user', child: Text('delegated_user')),
                ],
                onChanged: (v) => role = v ?? role,
                decoration: const InputDecoration(labelText: 'Rôle'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await EmployeeService(context.read<AuthProvider>().api).create({
        'name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'position': position.text.trim().isEmpty ? null : position.text.trim(),
        'role': role,
      });
      if (mounted) setState(() => _future = _load());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employés'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.person_add),
      ),
      body: FutureBuilder<List<EmployeeModel>>(
        future: _future!,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final msg = snap.error is ApiException
                ? (snap.error as ApiException).message
                : snap.error.toString();
            return Center(child: Text(msg));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) return const Center(child: Text('Aucun employé'));
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = items[i];
                return ListTile(
                  title: Text(e.user?.name ?? 'Employé #${e.id}'),
                  subtitle: Text(
                    '${e.user?.email ?? ''} · ${e.position ?? '-'} · ${e.user?.role ?? ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      try {
                        await EmployeeService(context.read<AuthProvider>().api)
                            .delete(e.id);
                        if (mounted) setState(() => _future = _load());
                      } on ApiException catch (err) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err.message)));
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
