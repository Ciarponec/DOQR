import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/providers.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('DOQR Owner Panel'),
        actions: [
          IconButton(onPressed: () async { await Supabase.instance.client.auth.signOut(); if (mounted) Navigator.of(context).pushReplacementNamed('/'); }, icon: const Icon(Icons.logout)),
        ],
      ),
      body: FutureBuilder(
        future: api.listRings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data ?? [];
          return ListView(
            children: [
              ListTile(title: const Text('Kapilarim'), onTap: () => Navigator.pushNamed(context, '/doors-manage')),
              ListTile(title: const Text('QR ile ring testi'), onTap: () => Navigator.pushNamed(context, '/qr-ring')),
              ListTile(title: const Text('QR token yonetimi'), onTap: () => Navigator.pushNamed(context, '/qr-token-manage')),
              ListTile(title: const Text('Share token olustur'), onTap: () => Navigator.pushNamed(context, '/share-create')),
              ListTile(title: const Text('Share token kabul et'), onTap: () => Navigator.pushNamed(context, '/share-accept')),
              const Divider(),
              ...items.map((r) => ListTile(
                    title: Text('Ring ${r.id.substring(0, 8)} - ${r.status}'),
                    subtitle: Text(r.createdAt.toLocal().toString()),
                    trailing: IconButton(
                      icon: const Icon(Icons.lock_open),
                      onPressed: loading ? null : () async {
                        setState(() => loading = true);
                        try {
                          await api.requestUnlock(doorId: r.doorId, reason: 'manual');
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock request gonderildi')));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        } finally { if (mounted) setState(() => loading = false); }
                      },
                    ),
                    onTap: () => Navigator.pushNamed(context, '/chat', arguments: r.id),
                  )),
            ],
          );
        },
      ),
    );
  }
}
