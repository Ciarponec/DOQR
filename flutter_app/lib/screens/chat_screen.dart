import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('Chat ${widget.ringId.substring(0, 8)}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: api.watchChat(widget.ringId),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final m = items[i];
                    return ListTile(
                      title: Text(m.text),
                      subtitle: Text('${m.senderType} - ${m.createdAt.toLocal()}'),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: 'Mesaj'))),
                IconButton(
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
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
