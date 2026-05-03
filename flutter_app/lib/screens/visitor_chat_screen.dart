import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: api.watchChat(widget.ringId),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                return ListView(
                  children: items
                      .map((m) => ListTile(
                            title: Text(m.text),
                            subtitle: Text('${m.senderType} - ${m.createdAt.toLocal()}'),
                          ))
                      .toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: 'Mesajiniz'))),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sending
                      ? null
                      : () async {
                          final text = input.text.trim();
                          if (text.isEmpty) return;
                          setState(() => sending = true);
                          try {
                            await api.sendVisitorMessage(
                              ringId: widget.ringId,
                              visitorSessionToken: widget.visitorSessionToken,
                              message: text,
                            );
                            input.clear();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          } finally {
                            if (mounted) setState(() => sending = false);
                          }
                        },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
