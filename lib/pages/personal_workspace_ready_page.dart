import 'package:flutter/material.dart';

import '../services/app_account_service.dart';
import '../services/managed_member_workspace_service.dart';
import 'personal_schedule_page.dart';
import 'personal_training_log_workspace_page.dart';
import 'personal_my_page.dart';

class PersonalWorkspaceReadyPage extends StatefulWidget {
  const PersonalWorkspaceReadyPage({
    super.key,
    required this.service,
    required this.uid,
    this.memberGateway,
  });

  final AppAccountService service;
  final String uid;
  final ManagedMemberWorkspaceGateway? memberGateway;

  @override
  State<PersonalWorkspaceReadyPage> createState() =>
      _PersonalWorkspaceReadyPageState();
}

class _PersonalWorkspaceReadyPageState
    extends State<PersonalWorkspaceReadyPage> {
  late final ManagedMemberWorkspaceGateway _gateway;

  @override
  void initState() {
    super.initState();
    _gateway = widget.memberGateway ??
        FirebaseManagedMemberWorkspaceGateway(uid: widget.uid);
  }

  Future<void> _openCreateMember() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateManagedMemberDialog(gateway: _gateway),
    );
  }

  Future<void> _transition(
    ManagedMemberSummary member,
    String nextState,
  ) async {
    try {
      await _gateway.transitionMember(
        memberId: member.memberId,
        nextState: nextState,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(managedMemberErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('personal_home'),
      appBar: AppBar(
        title: const Text('홈'),
        actions: [
          IconButton(
            key: const Key('open_personal_my_page'),
            tooltip: '마이페이지',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PersonalMyPage(
                  uid: widget.uid,
                  accountService: widget.service,
                  memberGateway: _gateway,
                ),
              ),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(child: _buildMemberManagement()),
    );
  }

  Widget _buildMemberManagement() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<ManagedMemberUsage>(
                stream: _gateway.watchUsage(),
                builder: (context, snapshot) {
                  final usage = snapshot.data ??
                      const ManagedMemberUsage(count: 0, limit: 10);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '관리 중인 회원',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${usage.lifetimeQualifiedCount}명 · ${usage.tier}',
                            key: const Key('managed_member_usage'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open_personal_schedules'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PersonalSchedulePage(uid: widget.uid),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('레슨일정 관리'),
              ),
              const SizedBox(height: 12),
              StreamBuilder<ManagedMemberUsage>(
                stream: _gateway.watchUsage(),
                builder: (context, snapshot) {
                  final usage = snapshot.data ??
                      const ManagedMemberUsage(count: 0, limit: 10);
                  return FilledButton.icon(
                    key: const Key('create_managed_member_button'),
                    onPressed: _openCreateMember,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(usage.count == 0 ? '첫 회원 등록' : '회원 등록'),
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ManagedMemberSummary>>(
                  stream: _gateway.watchMembers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('회원 목록을 불러오지 못했어요.'),
                      );
                    }
                    final members = snapshot.data ?? const [];
                    if (members.isEmpty) {
                      return const Center(child: Text('첫 회원을 등록해보세요.'));
                    }
                    return ListView.separated(
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return ListTile(
                          key: Key('managed_member_${member.memberId}'),
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_rounded),
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            member.phone.isEmpty
                                ? _stateLabel(member.managementState)
                                : '${member.phone} · ${_stateLabel(member.managementState)}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PersonalTrainingLogWorkspacePage(
                                uid: widget.uid,
                                memberId: member.memberId,
                                memberName: member.name,
                              ),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (state) => _transition(member, state),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'active', child: Text('활성')),
                              PopupMenuItem(
                                  value: 'paused', child: Text('회원권 정지')),
                              PopupMenuItem(
                                  value: 'dormant', child: Text('휴면')),
                              PopupMenuItem(
                                  value: 'expired', child: Text('만료')),
                              PopupMenuItem(
                                  value: 'deleted', child: Text('삭제')),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _stateLabel(String state) => switch (state) {
        'paused' => '회원권 정지',
        'dormant' => '휴면',
        'expired' => '만료',
        _ => '활성',
      };
}

class _CreateManagedMemberDialog extends StatefulWidget {
  const _CreateManagedMemberDialog({required this.gateway});

  final ManagedMemberWorkspaceGateway gateway;

  @override
  State<_CreateManagedMemberDialog> createState() =>
      _CreateManagedMemberDialogState();
}

class _CreateManagedMemberDialogState
    extends State<_CreateManagedMemberDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _activityRegionController = TextEditingController();
  final _noteController = TextEditingController();
  String? _gender;
  late final String _idempotencyKey =
      'member-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _activityRegionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = '회원 이름을 입력해주세요.');
      return;
    }
    if (_gender == null ||
        _phoneController.text.trim().isEmpty ||
        _activityRegionController.text.trim().isEmpty) {
      setState(() => _errorMessage = '성별·전화번호·활동 지역을 모두 입력해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.createMember(
        idempotencyKey: _idempotencyKey,
        name: name,
        gender: _gender!,
        phone: _phoneController.text.trim(),
        activityRegion: _activityRegionController.text.trim(),
        note: _noteController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = managedMemberErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('회원 등록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('managed_member_name'),
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            DropdownButtonFormField<String>(
              key: const Key('managed_member_gender'),
              initialValue: _gender,
              decoration: const InputDecoration(labelText: '성별'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('남성')),
                DropdownMenuItem(value: 'female', child: Text('여성')),
              ],
              onChanged:
                  _saving ? null : (value) => setState(() => _gender = value),
            ),
            TextField(
              key: const Key('managed_member_phone'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '전화번호'),
            ),
            TextField(
              key: const Key('managed_member_activity_region'),
              controller: _activityRegionController,
              decoration: const InputDecoration(labelText: '활동 지역'),
            ),
            TextField(
              key: const Key('managed_member_note'),
              controller: _noteController,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                key: const Key('managed_member_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save_managed_member_button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '저장 중' : '저장'),
        ),
      ],
    );
  }
}
