import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/providers.dart';
import '../widgets/app_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return AppShell(
      title: 'DOQR Panel',
      actions: [
        IconButton(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (mounted) Navigator.of(context).pushReplacementNamed('/');
          },
          icon: const Icon(Icons.logout),
        )
      ],
      child: FutureBuilder(
        future: api.listRings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data ?? [];
          return ListView(
            children: [
              const SectionLabel('Hizli Islemler'),
              ElevCard(
                child: Wrap(
                  runSpacing: 10,
                  spacing: 10,
                  children: [
                    _action(context, Icons.home_work_rounded, 'Kapilarim', '/doors-manage'),
                    _action(context, Icons.qr_code_scanner_rounded, 'QR ile Ring', '/qr-ring'),
                    _action(context, Icons.qr_code_2_rounded, 'QR Token', '/qr-token-manage'),
                    _action(context, Icons.group_add_rounded, 'Share Uret', '/share-create'),
                    _action(context, Icons.key_rounded, 'Share Kabul', '/share-accept'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SectionLabel('Ring Gecmisi'),
              ...items.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Ring ${r.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${r.status} • ${r.createdAt.toLocal()}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.lock_open_rounded),
                          onPressed: loading
                              ? null
                              : () async {
                                  setState(() => loading = true);
                                  try {
                                    await api.requestUnlock(doorId: r.doorId, reason: 'manual');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock request gonderildi')));
                                    }
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                  } finally {
                                    if (mounted) setState(() => loading = false);
                                  }
                                },
                        ),
                        onTap: () => Navigator.pushNamed(context, '/chat', arguments: r.id),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, String route) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 58) / 2,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)))],
          ),
        ),
      ),
    );
  }
}
