import 'package:flutter/material.dart';

class ShadcnCommandItem {
  final String label;
  final VoidCallback onSelect;

  ShadcnCommandItem({
    required this.label,
    required this.onSelect,
  });
}

class ShadcnCommandPalette {
  static void show(
      BuildContext context, {
        required List<ShadcnCommandItem> items,
      }) {
    showDialog(
      context: context,
      builder: (_) => _ShadcnCommandDialog(items: items),
    );
  }
}

class _ShadcnCommandDialog extends StatefulWidget {
  final List<ShadcnCommandItem> items;

  const _ShadcnCommandDialog({
    super.key,
    required this.items,
  });

  @override
  State<_ShadcnCommandDialog> createState() =>
      _ShadcnCommandDialogState();
}

class _ShadcnCommandDialogState
    extends State<_ShadcnCommandDialog> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((e) => e.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: "Search…",
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var item in filtered)
                      ListTile(
                        title: Text(item.label),
                        onTap: () {
                          Navigator.pop(context);
                          item.onSelect();
                        },
                      )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
