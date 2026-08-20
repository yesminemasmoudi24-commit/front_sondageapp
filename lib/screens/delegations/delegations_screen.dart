import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/delegation_model.dart';
import '../../models/employee_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/delegation_service.dart';
import '../../services/employee_service.dart';

class DelegationsScreen extends StatefulWidget {
  const DelegationsScreen({super.key});

  @override
  State<DelegationsScreen> createState() => _DelegationsScreenState();
}

class _DelegationsScreenState extends State<DelegationsScreen> {
  final List<DelegationModel> _items = [];
  bool _loading = true;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  DelegationService get _service =>
      DelegationService(context.read<AuthProvider>().api);

  Future<void> _refresh() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return _fmt(d);
  }

  Future<void> _create() async {
    if (_creating) return;
    final api = context.read<AuthProvider>().api;

    List<EmployeeModel> employees;
    try {
      employees = await EmployeeService(api).list();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    // Backend refuse les admins ; on propose employés / délégués uniquement.
    final candidates = employees
        .where((e) => e.user != null && e.user!.role != 'admin')
        .toList();

    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun utilisateur à déléguer')),
      );
      return;
    }

    int? selectedUserId = candidates.first.user!.id;
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 30));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nouvelle délégation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedUserId,
                  items: [
                    for (final e in candidates)
                      DropdownMenuItem(
                        value: e.user!.id,
                        child: Text('${e.user!.name} (${e.user!.email})'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => selectedUserId = v),
                  decoration: const InputDecoration(labelText: 'Utilisateur'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Début : ${_fmt(start)}'),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (p != null) setLocal(() => start = p);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Fin : ${_fmt(end)}'),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: end,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (p != null) setLocal(() => end = p);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selectedUserId == null || !mounted) return;

    setState(() => _creating = true);
    try {
      final created = await _service.create(
        delegatedUserId: selectedUserId!,
        startDate: _fmt(start),
        endDate: _fmt(end),
      );
      if (!mounted) return;

      // Mise à jour immédiate avec la réponse POST du backend.
      setState(() {
        _items.removeWhere((d) => d.id == created.id);
        _items.insert(0, created);
        _creating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Délégation créée')),
      );

      // Resync serveur (au cas où).
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _delete(DelegationModel d) async {
    try {
      await _service.delete(d.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((item) => item.id == d.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Délégation annulée')),
      );
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Délégations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _creating ? null : _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _creating ? null : _create,
        child: _creating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('Aucune délégation')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final d = _items[i];
          return ListTile(
            title: Text(d.delegatedUser?.name ?? 'Délégation #${d.id}'),
            subtitle: Text(
              '${d.status} · ${_shortDate(d.startDate)} → ${_shortDate(d.endDate)}'
              '${d.isCurrentlyActive ? ' · en cours' : ''}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(d),
            ),
          );
        },
      ),
    );
  }
}
