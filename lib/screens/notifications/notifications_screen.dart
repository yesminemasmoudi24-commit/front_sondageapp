import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../providers/notification_provider.dart';
import '../../theme/kpit_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (provider.unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: KpitTheme.lime,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  provider.badgeLabel,
                  style: const TextStyle(
                    color: KpitTheme.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.refresh,
          ),
        ],
      ),
      body: provider.loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: KpitTheme.lime))
          : provider.error != null && items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(provider.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: provider.refresh,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: KpitTheme.lime,
                  onRefresh: provider.refresh,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 160),
                            Center(child: Text('Aucune notification')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: KpitTheme.border),
                          itemBuilder: (context, i) {
                            final n = items[i];
                            return ListTile(
                              leading: Icon(
                                n.isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                                color: n.isRead
                                    ? KpitTheme.muted
                                    : KpitTheme.lime,
                              ),
                              title: Text(
                                n.message,
                                style: TextStyle(
                                  fontWeight: n.isRead
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(n.createdAt ?? ''),
                              onTap: n.isRead
                                  ? null
                                  : () async {
                                      try {
                                        await context
                                            .read<NotificationProvider>()
                                            .markAsRead(n.id);
                                      } on ApiException catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(e.message)),
                                        );
                                      }
                                    },
                            );
                          },
                        ),
                ),
    );
  }
}
