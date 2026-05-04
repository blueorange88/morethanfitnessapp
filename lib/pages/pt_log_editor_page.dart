import 'package:flutter/material.dart';

class PTLogEditorPage extends StatefulWidget {
final int sessionNum;
final bool isPremium; // 유료 사용자 여부 (더미/AI 활성화 제어)

const PTLogEditorPage({
super.key,
required this.sessionNum,
this.isPremium = true // 테스트를 위해 기본 true 설정
});

@override
State<PTLogEditorPage> createState() => _PTLogEditorPageState();
}

class _PTLogEditorPageState extends State<PTLogEditorPage> {
String _inputMode = 'dummy'; // 초기 모드: 애니더미
String _viewMode = 'front';  // 전면/후면 전환
String? _selectedExercise;   // 선택된 운동 부위 또는 종목명
List<Map<String, String>> _setRecords = []; // 세트 데이터

// 인체 부위 좌표 데이터 (비율 기준)
final Map<String, List<Map<String, dynamic>>> _muscleData = {
'front': [
{'name': 'Chest', 'top': 0.22, 'left': 0.35, 'w': 0.3, 'h': 0.08},
{'name': 'Abs', 'top': 0.35, 'left': 0.42, 'w': 0.16, 'h': 0.12},
{'name': 'Quads', 'top': 0.55, 'left': 0.32, 'w': 0.36, 'h': 0.18},
{'name': 'Shoulders', 'top': 0.18, 'left': 0.28, 'w': 0.44, 'h': 0.07},
],
'back': [
{'name': 'Traps', 'top': 0.15, 'left': 0.38, 'w': 0.24, 'h': 0.08},
{'name': 'Lats', 'top': 0.25, 'left': 0.32, 'w': 0.36, 'h': 0.15},
{'name': 'Glutes', 'top': 0.45, 'left': 0.35, 'w': 0.3, 'h': 0.12},
],
};

void _onExerciseSelect(String name) {
setState(() {
_selectedExercise = name;
// 부위 선택 시 기본 3세트 자동 생성
if (_setRecords.isEmpty) {
_setRecords = List.generate(3, (i) => {'set': '${i + 1}', 'weight': '0', 'reps': '0'});
}
});
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.white,
appBar: AppBar(
title: Text("SESSION #${widget.sessionNum} - ${_selectedExercise ?? '부위 선택'}"),
backgroundColor: const Color(0xFF6200EE),
actions: [
if (_inputMode == 'dummy')
IconButton(
icon: const Icon(Icons.sync_alt),
onPressed: () => setState(() => _viewMode = _viewMode == 'front' ? 'back' : 'front'),
),
],
),
body: Column(
children: [
_buildModeSelector(),
Expanded(flex: 5, child: _buildMainInputArea()),
const Divider(height: 1, color: Colors.black26),
Expanded(flex: 5, child: _buildSetListArea()),
_buildSaveButton(),
],
),
);
}

// --- [상단 입력 모드 선택기] ---
  Widget _buildModeSelector() {
    final modes = {'free': '자유작성', 'category': '카테고리', 'dummy': '애니더미', 'ai': 'AI음성'};
    return Container(
      // color: Colors.grey[100], // ❌ 여기에 있으면 에러 발생 (삭제)
      decoration: BoxDecoration(
        color: Colors.grey[100], // ✅ BoxDecoration 안으로 이동
      ),
      child: Row(
        children: modes.entries.map((e) {
          bool isSelected = _inputMode == e.key;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _inputMode = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFF6200EE) : Colors.transparent, width: 2.5)),
                ),
                child: Center(
                  child: Text(e.value,
                      style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF6200EE) : Colors.black54)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

// --- [중앙 입력 영역 분기] ---
Widget _buildMainInputArea() {
switch (_inputMode) {
case 'dummy': return _buildAnatomyView();
case 'category': return _buildCategoryView();
case 'free': return _buildFreeInputView();
default: return const Center(child: Text("AI 음성 인식 대기 중..."));
}
}

// 1. 애니더미 뷰
Widget _buildAnatomyView() {
return LayoutBuilder(builder: (context, constraints) {
return Stack(
alignment: Alignment.center,
children: [
const Icon(Icons.person, size: 250, color: Colors.black12), // 실제 이미지는 Image.asset으로 대체 가능
..._muscleData[_viewMode]!.map((m) => Positioned(
top: constraints.maxHeight * m['top'],
left: constraints.maxWidth * m['left'],
child: GestureDetector(
onTap: () => _onExerciseSelect(m['name']),
child: Container(
width: constraints.maxWidth * m['w'],
height: constraints.maxHeight * m['h'],
decoration: BoxDecoration(
color: _selectedExercise == m['name'] ? Colors.orange.withOpacity(0.4) : Colors.blue.withOpacity(0.05),
border: Border.all(color: _selectedExercise == m['name'] ? Colors.orange : Colors.blue.withOpacity(0.3)),
borderRadius: BorderRadius.circular(4),
),
child: Center(child: Text(m['name'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
),
),
)),
],
);
});
}

// 2. 카테고리 뷰
Widget _buildCategoryView() {
final list = ["Bench Press", "Squat", "Deadlift", "Lat Pulldown", "Shoulder Press"];
return ListView(
children: list.map((ex) => ListTile(
title: Text(ex, style: const TextStyle(fontSize: 14)),
trailing: const Icon(Icons.add, size: 16),
onTap: () => _onExerciseSelect(ex),
)).toList(),
);
}

// 3. 자유 작성 뷰
Widget _buildFreeInputView() {
return Padding(
padding: const EdgeInsets.all(20.0),
child: TextField(
decoration: const InputDecoration(labelText: "운동 종목 직접 입력", border: OutlineInputBorder()),
onSubmitted: (val) => _onExerciseSelect(val),
),
);
}

// --- [하단 세트 기록 영역] ---
Widget _buildSetListArea() {
if (_selectedExercise == null) return const Center(child: Text("운동 부위나 종목을 선택해 주세요."));
return Column(
children: [
Padding(
padding: const EdgeInsets.all(12),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text("$_selectedExercise 기록", style: const TextStyle(fontWeight: FontWeight.bold)),
TextButton.icon(
onPressed: () => setState(() => _setRecords.add({'set': '${_setRecords.length + 1}', 'weight': '0', 'reps': '0'})),
icon: const Icon(Icons.add, size: 14), label: const Text("세트추가"),
),
],
),
),
Expanded(
child: ListView.builder(
itemCount: _setRecords.length,
itemBuilder: (context, index) => _buildSetRow(index),
),
),
],
);
}

Widget _buildSetRow(int index) {
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
child: Row(
children: [
Text("${index + 1} SET", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
const SizedBox(width: 25),
_inputField(index, 'weight', 'kg'),
const SizedBox(width: 20),
_inputField(index, 'reps', '회'),
const Spacer(),
IconButton(
icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
onPressed: () => setState(() => _setRecords.removeAt(index)),
),
],
),
);
}

Widget _inputField(int index, String key, String unit) {
return Row(
children: [
SizedBox(
width: 50,
child: TextField(
keyboardType: TextInputType.number,
textAlign: TextAlign.center,
style: const TextStyle(fontSize: 13),
decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
onChanged: (val) => _setRecords[index][key] = val,
),
),
const SizedBox(width: 4),
Text(unit, style: const TextStyle(fontSize: 11, color: Colors.grey)),
],
);
}

Widget _buildSaveButton() {
return Container(
width: double.infinity,
padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
child: ElevatedButton(
style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EE), padding: const EdgeInsets.symmetric(vertical: 16)),
  onPressed: () {
    // 팩트: 선택된 운동과 총 세트 수를 문자열로 만들어 전달합니다.
    String resultText = "${_selectedExercise ?? '미기록'} (${_setRecords.length}세트)";
    Navigator.pop(context, resultText);
  },
child: const Text("저장 및 세션 기록", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
),
);
}
}