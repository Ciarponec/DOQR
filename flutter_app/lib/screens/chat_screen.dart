import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../widgets/app_shell.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String ringId;
  const ChatScreen({super.key, required this.ringId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final input = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final api = ref.read(doqrApiProvider);
    return AppShell(
      title: 'Ring Chat',
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
                      alignment: m.senderType == 'visitor' ? Alignment.centerLeft : Alignment.centerRight,
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
              Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: 'Mesaj'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        final text = input.text.trim();
                        if (text.isEmpty) return;
                        setState(() => loading = true);
                        try {
                          await api.sendOwnerMessage(ringId: widget.ringId, message: text);
                          input.clear();
                        } finally {
                          if (mounted) setState(() => loading = false);
                        }
                      },
                child: const Text('Gonder'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
