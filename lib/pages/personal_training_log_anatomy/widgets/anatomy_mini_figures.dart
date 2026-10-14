import 'package:flutter/material.dart';

import '../models/anatomy_log.dart';
import '../models/body_map_data.dart';
import 'body_map_canvas.dart';

/// 레슨일지 목록의 펼친 카드에 넣는 작은 몸 그림(앞·뒤). 운동한 부위와 통증·주의·
/// 가동성 점을 보여주는 읽기 전용이다.
class AnatomyMiniFigures extends StatefulWidget {
  const AnatomyMiniFigures({super.key, required this.records});

  final List<AnatomyLogRecord> records;

  @override
  State<AnatomyMiniFigures> createState() => _AnatomyMiniFiguresState();
}

class _AnatomyMiniFiguresState extends State<AnatomyMiniFigures> {
  late final Future<BodyMapData> _mapFuture = BodyMapData.load();

  BodyGender get _gender {
    for (final record in widget.records) {
      if (record.bodyGender != BodyGender.unspecified) return record.bodyGender;
    }
    return BodyGender.unspecified;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BodyMapData>(
      future: _mapFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox(height: 150);
        return Row(
          key: const ValueKey<String>('log_card_figures'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final view in BodyView.values) ...[
              SizedBox(
                width: 104,
                child: IgnorePointer(
                  child: BodyMapCanvas(
                    scene: data.sceneFor(_gender, view),
                    viewBox: data.viewBox,
                    records: widget.records,
                    onTapped: (_) {},
                    pinsOnly: true,
                  ),
                ),
              ),
              if (view == BodyView.front) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}
