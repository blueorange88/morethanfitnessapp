import 'package:flutter/material.dart';
import 'package:mtf_app/pages/binder_card.dart';

class BinderCarouselPage extends StatefulWidget {
  const BinderCarouselPage({super.key, required this.members});
  final List<Member> members;

  @override
  State<BinderCarouselPage> createState() => _BinderCarouselPageState();
}

class _BinderCarouselPageState extends State<BinderCarouselPage> {
  late final PageController _pc;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.92, keepPage: true);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('회원 바인더')),
      body: SafeArea(
        child: PageView.builder(
          key: const PageStorageKey('binder_carousel'), // ✅ 안정화
          controller: _pc,
          physics: const PageScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final m = members[index];

            return Center(
              child: BinderCard(
                key: ValueKey(m.id), // ✅ 제일 중요! (id 없으면 ValueKey(index))
                member: m,
                onOpenJournal: () async {},
                onOpenEdit: () async {},
                onOpenContract: () async {},
                onLongPress: () {},
              ),
            );
          },
        ),
      ),
    );
  }
}