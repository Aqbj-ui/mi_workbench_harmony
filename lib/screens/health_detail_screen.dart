// 健康评分详情：总分 + 四维度明细 + 算法说明 + 改进建议 + 睡眠趋势
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/health_service.dart';

class HealthDetailScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigate;
  const HealthDetailScreen({super.key, this.onNavigate});
  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  HealthBreakdown? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await HealthService.instance.load();
    if (mounted) {
      setState(() {
        _data = b;
        _loading = false;
      });
    }
  }

  String _grade(double v) {
    if (v >= 85) return '优秀';
    if (v >= 70) return '良好';
    if (v >= 50) return '一般';
    if (v >= 25) return '偏弱';
    return '待改善';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康评分详情'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading || _data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(total: _data!.total, grade: _grade(_data!.total)),
                  const SizedBox(height: 16),
                  ..._data!.dims.map((d) => _DimCard(
                        dim: d,
                        onImprove: widget.onNavigate == null
                            ? null
                            : () => widget.onNavigate!.call(d.key == 'weight'
                                ? 'weight'
                                : d.key == 'exercise'
                                    ? 'exercise'
                                    : d.key == 'habit'
                                        ? 'habit'
                                        : 'device'),
                      )),
                  const SizedBox(height: 8),
                  _SleepTrend(
                    values: _data!.sleepTrend,
                    days: _data!.sleepTrendDays,
                  ),
                  const SizedBox(height: 12),
                  _NoteCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final double total;
  final String grade;
  const _Header({required this.total, required this.grade});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.sidebarGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(total.toStringAsFixed(0),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const Text(' / 100',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('健康综合评分',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(grade,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('满分 100 = 四维各 25',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('运动 · 习惯 · 睡眠 · 体重，四维度等权重',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DimCard extends StatelessWidget {
  final HealthDim dim;
  final VoidCallback? onImprove;
  const _DimCard({required this.dim, this.onImprove});
  @override
  Widget build(BuildContext context) {
    final pct = (dim.score / 25).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(dim.icon, color: dim.color, size: 22),
              const SizedBox(width: 8),
              Text(dim.name,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const Spacer(),
              Text('${dim.score.toStringAsFixed(0)} / 25',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: dim.color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppTheme.subtleBg,
              valueColor: AlwaysStoppedAnimation<Color>(dim.color),
            ),
          ),
          const SizedBox(height: 10),
          Text(dim.detail,
              style: TextStyle(fontSize: 13, color: AppTheme.textMain)),
          const SizedBox(height: 8),
          _Row(label: '算法', text: dim.formula),
          _Row(label: '建议', text: dim.advice),
          if (onImprove != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onImprove,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('去完善'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String text;
  const _Row({required this.label, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.subtleBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _SleepTrend extends StatelessWidget {
  final List<double> values;
  final List<String> days;
  const _SleepTrend({required this.values, required this.days});
  @override
  Widget build(BuildContext context) {
    final maxH = 9.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              Text('近 7 天睡眠',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
              const Spacer(),
              Text('达标线 7h',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final v = values[i];
                final h = ((v / maxH) * 100).clamp(0.0, 100).toDouble();
                final day = days[i].substring(5); // MM-dd
                final reached = v >= 7;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (v > 0)
                        Text(v.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 10,
                                color: reached ? Colors.indigo : AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: reached ? Colors.indigo : Colors.indigo.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(day,
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '评分仅供自我激励参考，不构成医疗建议。四维等权重各 25 分，'
              '未设定目标（运动周目标 / 体重目标）时该维度的满分门槛会放宽。',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
