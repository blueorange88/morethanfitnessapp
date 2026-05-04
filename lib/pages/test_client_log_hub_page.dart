import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:signature/signature.dart';
import 'pt_log_editor_page.dart';

class TestClientLogHubPage extends StatefulWidget {
  const TestClientLogHubPage({super.key});

  @override
  State<TestClientLogHubPage> createState() => _TestClientLogHubPageState();
}

class _TestClientLogHubPageState extends State<TestClientLogHubPage> {
  final Color primaryColor = const Color(0xFF1A237E);
  final Color headerColor = const Color(0xFFE0F7FA);

  Map<int, String> sessionLogs = {10: "작성하려면 터치", 9: "데드리프트 하체 완료", 8: "벤치프레스 완료"};

  // [팩트] 서명 상태 관리 (고객/트레이너 각각 관리)
  Map<int, bool> clientSigned = {8: true, 9: true};
  Map<int, bool> trainerSigned = {8: true, 9: false};

  String registrationStatus = "재등록 3회차";
  SignatureController? _signatureController;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _signatureController?.dispose();
    super.dispose();
  }

  // [팩트] 서명 오버레이 (isClient 변수로 누구의 서명인지 구분)
  void _showSignatureOverlay(int sessionNum, bool isClient) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Signature",
      pageBuilder: (context, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 350,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
            ),
            child: Column(
              children: [
                Text("${isClient ? "고객" : "트레이너"} 서명 확인",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                    child: Signature(controller: _signatureController!, backgroundColor: const Color(0xFFF5F5F5)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () {
                          _signatureController?.clear();
                          Navigator.pop(context);
                        },
                        child: const Text("취소")
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: isClient ? Colors.red : primaryColor),
                      onPressed: () {
                        setState(() {
                          if (isClient) {
                            clientSigned[sessionNum] = true;
                          } else {
                            trainerSigned[sessionNum] = true;
                          }
                        });
                        _signatureController?.clear();
                        Navigator.pop(context);
                      },
                      child: Text("${isClient ? "고객" : "트레이너"} 확인", style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context)
        ),
        title: const Text("MORE THAN FITNESS",
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildCustomerInfoTable()),
          SliverToBoxAdapter(child: _buildPreviousNotes()),
          SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTableHeaderDelegate(headerColor: headerColor)
          ),
        ],
        body: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(color: Colors.black),
                  right: BorderSide(color: Colors.black),
                  bottom: BorderSide(color: Colors.black)
              )
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: 20,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black, thickness: 0.5),
            itemBuilder: (context, index) => _buildHistoryRow(20 - index),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfoTable() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
      child: Column(children: [
        _twoColumnRow("고객명", "김유신", "전화번호", "010-0000-0000"),
        const Divider(height: 1, color: Colors.black, thickness: 1.0),
        Row(children: [
          _labelCell("마지막레슨일"),
          _valueCell("2026.03.11"),
          _labelCell("레슨회차", width: 60),
          Expanded(child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black))),
              child: const Text("30 / 2", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
          )),
          _labelCell("등록구분", width: 60),
          Expanded(child: Center(child: Text(registrationStatus,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)))),
        ]),
      ]),
    );
  }

  Widget _buildPreviousNotes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: Colors.black))),
      child: Column(children: [
        Container(
            width: double.infinity,
            color: headerColor,
            padding: const EdgeInsets.all(4),
            child: const Center(child: Text("PREVIOUS NOTES / ISSUES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))
        ),
        const SizedBox(height: 35, child: Center(child: Text("특이사항 없음", style: TextStyle(fontSize: 10, color: Colors.grey)))),
        const Divider(height: 1, color: Colors.black, thickness: 1.0),
      ]),
    );
  }

  Widget _buildHistoryRow(int sessionNum) {
    bool cSigned = clientSigned[sessionNum] ?? false;
    bool tSigned = trainerSigned[sessionNum] ?? false;
    // [팩트] 둘 다 서명되어야 완전 잠금 처리
    bool isFullyLocked = cSigned && tSigned;

    return Stack(
      children: [
        SizedBox(
          height: 50,
          child: Row(children: [
            _cell("$sessionNum", width: 35, isBold: true, color: isFullyLocked ? Colors.grey : Colors.black),
            _cell("03.12", width: 50, fontSize: 9, color: Colors.grey),
            Expanded(child: InkWell(
              onTap: isFullyLocked ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => PTLogEditorPage(sessionNum: sessionNum))),
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  child: Text(sessionLogs[sessionNum] ?? "-",
                      style: TextStyle(fontSize: 9, color: isFullyLocked ? Colors.grey : Colors.black))
              ),
            )),
            // [팩트] 고객 서명 칸
            _signatureCell(cSigned, () => _showSignatureOverlay(sessionNum, true), "고객", 55),
            // [팩트] 트레이너 서명 칸
            _signatureCell(tSigned, () => _showSignatureOverlay(sessionNum, false), "강사", 55),
          ]),
        ),
        if (isFullyLocked)
          Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 4, color: Colors.red)),
      ],
    );
  }

  // 서명 공통 셀 유틸리티
  Widget _signatureCell(bool isSigned, VoidCallback onTap, String label, double width) {
    return InkWell(
      // 서명 완료 시 클릭(onTap)을 null로 설정하여 터치 차단
      onTap: isSigned ? null : onTap,
      child: Container(
          width: width,
          decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.black, width: 0.5))
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 기본 상태: "고객" 또는 "강사" 텍스트
              Center(
                  child: Text(label,
                      style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))
              ),
              // [팩트] 서명 완료 시 나타나는 반투명 오버레이
              if (isSigned)
                Container(
                  color: Colors.black.withOpacity(0.6), // 반투명 검은색
                  alignment: Alignment.center,
                  child: const Text(
                    "수정\n불가",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        height: 1.2
                    ),
                  ),
                ),
            ],
          )
      ),
    );
  }

  Widget _twoColumnRow(String l1, String v1, String l2, String v2) => Row(children: [_labelCell(l1), _valueCell(v1), _labelCell(l2), _valueCell(v2, showBorder: false)]);
  Widget _labelCell(String text, {double? width}) => Container(width: width ?? 70, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: headerColor, border: const Border(right: BorderSide(color: Colors.black))), child: Center(child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))));
  Widget _valueCell(String text, {bool showBorder = true}) => Expanded(child: Container(decoration: BoxDecoration(border: showBorder ? const Border(right: BorderSide(color: Colors.black)) : null), child: Center(child: Text(text, style: const TextStyle(fontSize: 10)))));
  static Widget _cell(String text, {double? width, double fontSize = 10, bool isBold = false, Color color = Colors.black}) => Container(width: width, alignment: Alignment.center, decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 0.5))), child: Text(text, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)));
}

class _StickyTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Color headerColor;
  _StickyTableHeaderDelegate({required this.headerColor});

  @override double get minExtent => 38.0;
  @override double get maxExtent => 38.0;

  @override
  Widget build(context, offset, overlaps) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: headerColor,
      border: const Border(bottom: BorderSide(color: Colors.black), left: BorderSide(color: Colors.black), right: BorderSide(color: Colors.black)),
    ),
    child: Row(children: [
      _staticCell("회차", width: 35),
      _staticCell("날짜", width: 50),
      Expanded(child: _staticCell("기록 요약")),
      _staticCell("고객", width: 55), // 너비 조정
      _staticCell("강사", width: 55, showBorder: false), // 트레이너 헤더 추가
    ]),
  );

  Widget _staticCell(String text, {double? width, bool showBorder = true}) => Container(
    width: width,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: showBorder ? const Border(right: BorderSide(color: Colors.black, width: 0.5)) : null,
    ),
    child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
  );

  @override bool shouldRebuild(old) => false;
}