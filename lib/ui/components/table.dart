import 'package:flutter/material.dart';

class ShadcnTableHeader {
  final String label;
  ShadcnTableHeader(this.label);
}

class ShadcnTableRow {
  final List<String> cells;
  ShadcnTableRow(this.cells);
}

class ShadcnTable extends StatelessWidget {
  final List<ShadcnTableHeader> headers;
  final List<ShadcnTableRow> rows;

  const ShadcnTable({
    super.key,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Table(
      columnWidths: {
        for (int i = 0; i < headers.length; i++) i: const FlexColumnWidth()
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: cs.outline.withOpacity(0.3)),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: cs.surfaceVariant),
          children: [
            for (var h in headers)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  h.label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant),
                ),
              )
          ],
        ),
        for (var row in rows)
          TableRow(
            children: [
              for (var cell in row.cells)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(cell),
                )
            ],
          ),
      ],
    );
  }
}
