import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatsPage extends StatefulWidget {
  final Map<String, dynamic> scheduleData;

  const StatsPage({
    Key? key,
    required this.scheduleData,
  }) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final NumberFormat _numberFormat = NumberFormat.decimalPattern('ko_KR');

  int _feePerSession = 1150000;
  late TextEditingController _feeController;

  int _yearSessions = 0;
  int _monthSessions = 0;
  int _weekSessions = 0;

  late List<int> _monthlyCounts; // 12개월
  late List<int> _weekdayCounts; // 월~일
  late Map<String, int> _typeCounts;

  double _reRegistrationRate = 0;
  double _newMemberInflowRate = 0;
  double _introRevenueRate = 0;
  double _sessionProgressRate = 0;

  late List<double> _momGrowth; // 전월 대비
  late List<double> _yoyGrowth; // 전년 대비 느낌용 더미/계산값

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController(
      text: _numberFormat.format(_feePerSession),
    );
    _monthlyCounts = List<int>.filled(12, 0);
    _weekdayCounts = List<int>.filled(7, 0);
    _typeCounts = {};
    _momGrowth = List<double>.filled(12, 0);
    _yoyGrowth = List<double>.filled(12, 0);
    _recalculateStats();
  }

  @override
  void didUpdateWidget(covariant StatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scheduleData, widget.scheduleData)) {
      _recalculateStats();
    }
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  void _applyFee() {
    final raw = _feeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수업당 금액을 숫자로 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _feePerSession = parsed;
      _feeController.text = _numberFormat.format(parsed);
      _feeController.selection = TextSelection.collapsed(
        offset: _feeController.text.length,
      );
    });
    _recalculateStats();
  }

  int _dayIndex(String day) {
    switch (day) {
      case '월':
        return 0;
      case '화':
        return 1;
      case '수':
        return 2;
      case '목':
        return 3;
      case '금':
        return 4;
      case '토':
        return 5;
      case '일':
        return 6;
      default:
        return -1;
    }
  }

  String _formatWon(int value) => '${_numberFormat.format(value)}원';

  void _recalculateStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final sundayThisWeek = mondayThisWeek.add(const Duration(days: 6));

    int yearSessions = 0;
    int monthSessions = 0;
    int weekSessions = 0;

    final monthly = List<int>.filled(12, 0);
    final weekday = List<int>.filled(7, 0);
    final typeCounts = <String, int>{};

    widget.scheduleData.forEach((key, value) {
      final parts = key.split('-');
      if (parts.length != 3) return;

      final offset = int.tryParse(parts[0]) ?? 0;
      final dayStr = parts[1];
      final dayIndex = _dayIndex(dayStr);
      if (dayIndex < 0) return;

      final baseDate =
      mondayThisWeek.add(Duration(days: 7 * offset + dayIndex));
      final baseDay = DateTime(baseDate.year, baseDate.month, baseDate.day);

      if (!baseDay.isBefore(mondayThisWeek) && !baseDay.isAfter(sundayThisWeek)) {
        weekSessions++;
      }

      if (baseDay.year == now.year) {
        yearSessions++;
        monthly[baseDay.month - 1]++;
        weekday[dayIndex]++;

        if (baseDay.month == now.month) {
          monthSessions++;
        }
      }

      String type = '기타';
      if (value is Map<String, dynamic>) {
        final rawType = value['type']?.toString() ?? '';
        switch (rawType) {
          case '레슨':
          case 'PT':
          case 'PT레슨':
            type = 'PT';
            break;
          case '그룹레슨':
          case '그룹':
            type = '그룹';
            break;
          case '상담':
            type = '상담';
            break;
          case 'OT':
            type = 'OT';
            break;
          case '필라테스':
            type = '필라테스';
            break;
          default:
            type = rawType.isEmpty ? '기타' : rawType;
        }
      }
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    });

    final momGrowth = <double>[
      6, 9, 12, 15, 17, 20, 22, 24, 26, 28, 30, 32,
    ];

    final yoyGrowth = <double>[
      4, 6, 8, 11, 13, 15, 18, 20, 22, 24, 26, 29,
    ];

    final int introRevenue = (yearSessions * _feePerSession * 0.18).round();
    final int totalRevenue = yearSessions * _feePerSession;

    final reRegRate = yearSessions == 0
        ? 0
        : ((typeCounts['PT'] ?? 0) + (typeCounts['필라테스'] ?? 0)) /
        math.max(1, yearSessions) *
        100;

    final newInflowRate =
    yearSessions == 0 ? 0 : (monthSessions / math.max(1, yearSessions)) * 100;

    final introRevenueRate =
    totalRevenue == 0 ? 0 : (introRevenue / totalRevenue) * 100;

    final progressRate =
    yearSessions == 0 ? 0 : (weekSessions / math.max(1, monthSessions)) * 100;

    setState(() {
      _yearSessions = yearSessions;
      _monthSessions = monthSessions;
      _weekSessions = weekSessions;
      _monthlyCounts = monthly;
      _weekdayCounts = weekday;
      _typeCounts = typeCounts;
      _momGrowth = momGrowth;
      _yoyGrowth = yoyGrowth;
      _reRegistrationRate = reRegRate.clamp(0.0, 100.0).toDouble();
      _newMemberInflowRate = newInflowRate.clamp(0.0, 100.0).toDouble();
      _introRevenueRate = introRevenueRate.clamp(0.0, 100.0).toDouble();
      _sessionProgressRate = progressRate.clamp(0.0, 100.0).toDouble();
    });
  }

  int get _yearRevenue => _yearSessions * _feePerSession;
  int get _monthRevenue => _monthSessions * _feePerSession;
  int get _weekRevenue => _weekSessions * _feePerSession;
  int get _avgSessionRevenue =>
      _yearSessions == 0 ? 0 : (_yearRevenue / _yearSessions).round();
  int get _introRevenue => (_yearRevenue * 0.18).round();

  @override
  Widget build(BuildContext context) {
    final hasData = widget.scheduleData.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          Column(
            children: [
              _StatsHeader(
                title: '운영통계',
                subtitle: '수업, 회원, 매출 흐름을 한눈에 확인해보세요',
                onBackTap: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeeControlCard(),
                      const SizedBox(height: 14),
                      _buildTopSummaryCards(),
                      const SizedBox(height: 18),
                      _buildGrowthChartCard(hasData),
                      const SizedBox(height: 18),
                      _buildRateCards(),
                      const SizedBox(height: 18),
                      _buildMiddleCharts(),
                      const SizedBox(height: 18),
                      _buildBottomInsightCards(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                child: Container(
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _FloatingPremiumGlassBanner(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('프리미엄 결제 기능은 준비중입니다.'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeControlCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '월 예상 매출 금액',
                suffixText: '원',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _applyFee,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: [
        _KpiCard(
          title: '총 매출액',
          value: _formatWon(_yearRevenue),
          subtitle: '전월 대비 +8.2%',
          icon: Icons.paid_outlined,
          colors: const [Color(0xFFFF6A00), Color(0xFFFF7F11)],
        ),
        _KpiCard(
          title: '총 수업 수',
          value: '$_yearSessions',
          subtitle: '전월 대비 +14.2%',
          icon: Icons.fitness_center_rounded,
          colors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        _KpiCard(
          title: '신규 유입률',
          value: '${_newMemberInflowRate.toStringAsFixed(1)}%',
          subtitle: '이번 달 기준',
          icon: Icons.group_add_rounded,
          colors: const [Color(0xFFA855F7), Color(0xFF9333EA)],
        ),
        _KpiCard(
          title: '평균 수업 단가',
          value: _formatWon(_avgSessionRevenue),
          subtitle: '전월 대비 -1.8%',
          icon: Icons.show_chart_rounded,
          colors: const [Color(0xFF00B63E), Color(0xFF10B981)],
        ),
      ],
    );
  }

  Widget _buildGrowthChartCard(bool hasData) {
    return _DashboardCard(
      title: '전월 / 전년 대비 매출 추이',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendDot(color: Color(0xFFFF7A18), label: '전월 대비'),
          SizedBox(width: 10),
          _LegendDot(color: Color(0xFF3B82F6), label: '전년 대비'),
        ],
      ),
      child: hasData
          ? SizedBox(
        height: 260,
        child: _GrowthComboChart(
          bars: _momGrowth.map((e) => e.clamp(0.0, 36.0).toDouble()).toList(),
          line: _yoyGrowth.map((e) => e.clamp(0.0, 36.0).toDouble()).toList(),
        ),
      )
          : _emptyInfo('아직 스케줄 데이터가 없어서 그래프를 그릴 수 없어요.'),
    );
  }

  Widget _buildRateCards() {
    return Row(
      children: [
        Expanded(
          child: _DashboardCard(
            title: '재등록률',
            child: _DonutRate(
              value: _reRegistrationRate,
              label: '${_reRegistrationRate.toStringAsFixed(1)}%',
              subtitle: '재등록 비중',
              color: const Color(0xFF6D28D9),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DashboardCard(
            title: '소개건 관련 매출',
            child: _DonutRate(
              value: _introRevenueRate,
              label: '${_introRevenueRate.toStringAsFixed(1)}%',
              subtitle: _formatWon(_introRevenue),
              color: const Color(0xFFEA580C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleCharts() {
    return Column(
      children: [
        _DashboardCard(
          title: '요일별 수업 진행',
          child: SizedBox(
            height: 210,
            child: _WeekdayBarChart(values: _weekdayCounts),
          ),
        ),
        const SizedBox(height: 18),
        _DashboardCard(
          title: '수업 유형 비중',
          child: SizedBox(
            height: 220,
            child: _SessionTypeDonut(
              typeCounts: _typeCounts,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInsightCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SmallInsightCard(
                title: '이번 주 수업',
                value: '$_weekSessions회',
                subtitle: _formatWon(_weekRevenue),
                icon: Icons.calendar_view_week_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallInsightCard(
                title: '이번 달 수업',
                value: '$_monthSessions회',
                subtitle: _formatWon(_monthRevenue),
                icon: Icons.calendar_month_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallInsightCard(
                title: '수업 진행률',
                value: '${_sessionProgressRate.toStringAsFixed(1)}%',
                subtitle: '주간/월간 기준',
                icon: Icons.insights_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallInsightCard(
                title: '신규 유입',
                value: '${_newMemberInflowRate.toStringAsFixed(1)}%',
                subtitle: '월간 유입 지표',
                icon: Icons.person_add_alt_1_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyInfo(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.title,
    required this.subtitle,
    required this.onBackTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topPadding + 12,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF5B4BDB),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: onBackTap,
                    borderRadius: BorderRadius.circular(999),
                    child: const Center(
                      child: Text(
                        '<',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GrowthComboChart extends StatelessWidget {
  const _GrowthComboChart({
    required this.bars,
    required this.line,
  });

  final List<double> bars;
  final List<double> line;

  @override
  Widget build(BuildContext context) {
    const labels = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
    final double maxValue = math.max(
      10.0,
      [...bars, ...line].fold<double>(0.0, (p, e) => math.max(p, e)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = 190.0;
        final width = constraints.maxWidth;
        final stepX = width / 12;

        return Column(
          children: [
            SizedBox(
              height: chartHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridPainter(),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (index) {
                        final barHeight = (bars[index] / maxValue) * (chartHeight - 20);
                        return Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 24,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF7A18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LineChartPainter(
                        values: line,
                        maxValue: maxValue,
                        color: const Color(0xFF3B82F6),
                        stepX: stepX,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(12, (index) {
                return Expanded(
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (int i = 0; i <= 11; i++) {
      final x = size.width * (i / 11);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint..color = const Color(0xFFF1F5F9));
      paint.color = const Color(0xFFE5E7EB);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.maxValue,
    required this.color,
    required this.stepX,
  });

  final List<double> values;
  final double maxValue;
  final Color color;
  final double stepX;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final path = Path();
    final dotPaint = Paint()..color = color;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (int i = 0; i < values.length; i++) {
      final x = stepX * i + (stepX / 2);
      final y = size.height - ((values[i] / maxValue) * (size.height - 20)) - 10;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    for (int i = 0; i < values.length; i++) {
      final x = stepX * i + (stepX / 2);
      final y = size.height - ((values[i] / maxValue) * (size.height - 20)) - 10;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.maxValue != maxValue;
  }
}

class _DonutRate extends StatelessWidget {
  const _DonutRate({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  final double value;
  final String label;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = (value / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: _DonutPainter(
                  progress: progress,
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 14.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final bg = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bg);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _WeekdayBarChart extends StatelessWidget {
  const _WeekdayBarChart({
    required this.values,
  });

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final maxValue = math.max(1, values.fold<int>(0, math.max));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final ratio = values[index] / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${values[index]}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 120 * ratio.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      color: index >= 5
                          ? const Color(0xFFA855F7)
                          : const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[index],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SessionTypeDonut extends StatelessWidget {
  const _SessionTypeDonut({
    required this.typeCounts,
  });

  final Map<String, int> typeCounts;

  @override
  Widget build(BuildContext context) {
    final total = typeCounts.values.fold<int>(0, (a, b) => a + b);
    final entries = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = <Color>[
      const Color(0xFF4F46E5),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
      const Color(0xFF10B981),
      const Color(0xFFA855F7),
    ];

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CustomPaint(
            painter: _MultiDonutPainter(
              values: entries.map((e) => e.value.toDouble()).toList(),
              colors: colors,
            ),
            child: Center(
              child: Text(
                '$total회',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(entries.length, (index) {
              final item = entries[index];
              final color = colors[index % colors.length];
              final rate = total == 0 ? 0 : (item.value / total) * 100;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${item.value}회 · ${rate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MultiDonutPainter extends CustomPainter {
  const _MultiDonutPainter({
    required this.values,
    required this.colors,
  });

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;

    final stroke = 18.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    double start = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MultiDonutPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _SmallInsightCard extends StatelessWidget {
  const _SmallInsightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingPremiumGlassBanner extends StatelessWidget {
  const _FloatingPremiumGlassBanner({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 360,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A).withOpacity(0.72),
              const Color(0xFF4F46E5).withOpacity(0.42),
              const Color(0xFFF97316).withOpacity(0.30),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.16),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withOpacity(0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '프리미엄으로 업그레이드',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFFBBF24),
                                size: 18,
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            '프리미엄 결제하고 더 똑똑하게 관리하세요.\nAI 인사이트와 고급 통계 기능이 열립니다.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.4,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _MiniGlassFeatureChip(
                            icon: Icons.trending_up_rounded,
                            label: '신규 및 재등록 매출 분석',
                          ),
                          _MiniGlassFeatureChip(
                            icon: Icons.group_add_rounded,
                            label: '똑똑한 레슨일지 작성 ',
                          ),
                          _MiniGlassFeatureChip(
                            icon: Icons.pie_chart_outline_rounded,
                            label: '체계적인 계약서 시스템',
                          ),
                          _MiniGlassFeatureChip(
                            icon: Icons.calendar_view_week_rounded,
                            label: '편리한 스케줄 관리',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('자세히 보기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGlassFeatureChip extends StatelessWidget {
  const _MiniGlassFeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFFFBBF24),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsProChip extends StatelessWidget {
  const _StatsProChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}