import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../widgets/app_shell.dart';

class VisitorChatScreen extends ConsumerStatefulWidget {
  final String ringId;
  final String visitorSessionToken;

  const VisitorChatScreen({super.key, required this.ringId, required this.visitorSessionToken});

  @override
  ConsumerState<VisitorChatScreen> createState() => _VisitorChatScreenState();
}

class _VisitorChatScreenState extends ConsumerState<VisitorChatScreen> {
  final input = TextEditingController();
  bool sending = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return AppShell(
      title: 'Visitor Chat',
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: api.watchChat(widget.ringId),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = items[i];
                    return Align(
                      alignment: m.senderType == 'visitor' ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: ElevCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.text),
                              const SizedBox(height: 6),
                              Text('${m.senderType} • ${m.createdAt.toLocal()}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: 'Mesajiniz'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        final text = input.text.trim();
                        if (text.isEmpty) return;
                        setState(() => sending = true);
                        try {
                          await api.sendVisitorMessage(ringId: widget.ringId, visitorSessionToken: widget.visitorSessionToken, message: text);
                          input.clear();
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        } finally {
                          if (mounted) setState(() => sending = false);
                        }
                      },
                child: const Text('Gonder'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
