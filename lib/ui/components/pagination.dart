import 'package:flutter/material.dart';

class ShadcnPagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  const ShadcnPagination({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
        ),
        Text("$page / $totalPages",
            style: TextStyle(color: cs.onSurfaceVariant)),
        IconButton(
          onPressed:
          page < totalPages ? () => onChanged(page + 1) : null,
          icon: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
