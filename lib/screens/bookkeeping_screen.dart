// 记账 v2：双账本（个人/生意）+ 收支 + 预算 + 趋势 + 存钱计划
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/db_service.dart';
import '../services/nlp_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'saving_tab.dart';

class BookkeepingScreen extends StatefulWidget {
  const BookkeepingScreen({super.key});
  @override
  State<BookkeepingScreen> createState() => _BookkeepingScreenState();
}

class _BookkeepingScreenState extends State<BookkeepingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final GlobalKey<SavingTabState> _savingKey = GlobalKey<SavingTabState>();

  List<Transaction> _list = [];
  Map<String, double> _categorySum = {};
  ({double income, double expense, double balance}) _summary =
      (income: 0, expense: 0, balance: 0);

  String _period = 'week'; // week / month
  String? _ledger; // null=全部 / personal / business
  double _budget = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {}); // 切 Tab 时刷新 AppBar 按钮语义
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  DateTime _periodStart() {
    final now = DateTime.now();
    if (_period == 'week') {
      final from = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(from.year, from.month, from.day);
    }
    return DateTime(now.year, now.month, 1);
  }

  Future<void> _load() async {
    final from = _periodStart();
    final list = await DbService.instance.getTransactions(from: from, ledger: _ledger);
    final sum = await DbService.instance
        .getCategorySum(from: from, ledger: _ledger, type: TxType.expense);
    final summary = await DbService.instance.getSummary(from: from, ledger: _ledger);
    final budget = await SettingsService.instance.monthlyBudget;
    if (!mounted) return;
    setState(() {
      _list = list;
      _categorySum = sum;
      _summary = summary;
      _budget = budget;
    });
  }

  Future<void> _setBudget() async {
    final ctrl =
        TextEditingController(text: _budget > 0 ? _budget.toStringAsFixed(0) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置月度预算'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '¥ ', hintText: '如 3000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      await SettingsService.instance.setMonthlyBudget(double.tryParse(ctrl.text) ?? 0);
      await _load();
    }
  }

  // ---------- 记一笔（NLP 预填 + 手动纠正） ----------
  Future<void> _add() async {
    final ctrl = TextEditingController();
    String type = TxType.expense;
    String ledger = _ledger ?? Ledger.personal;
    String? previewCategory;
    double previewAmount = 0;
    bool touchedType = false;
    bool touchedLedger = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void reparse(String text) {
            if (text.trim().isEmpty) {
              setLocal(() {
                previewCategory = null;
                previewAmount = 0;
              });
              return;
            }
            final r = NlpService.parse(text);
            setLocal(() {
              previewCategory = r.category;
              previewAmount = r.amount;
              if (!touchedType) type = r.type;
              if (!touchedLedger) ledger = r.ledger;
            });
          }

          return AlertDialog(
            title: const Text('记一笔'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    maxLines: 2,
                    onChanged: reparse,
                    decoration: const InputDecoration(
                      hintText: '例：今天买了个榴莲120块 / 亚马逊回款8000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: TxType.expense, label: Text('支出')),
                      ButtonSegment(value: TxType.income, label: Text('收入')),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setLocal(() {
                      type = s.first;
                      touchedType = true;
                    }),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: Ledger.personal, label: Text('个人')),
                      ButtonSegment(value: Ledger.business, label: Text('生意')),
                    ],
                    selected: {ledger},
                    onSelectionChanged: (s) => setLocal(() {
                      ledger = s.first;
                      touchedLedger = true;
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (previewCategory != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '识别结果：${Ledger.label(ledger)} · ${TxType.label(type)} · $previewCategory · ¥${previewAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryDark),
                      ),
                    )
                  else
                    const Text('输入后会自动识别金额、收支方向和分类',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
            ],
          );
        },
      ),
    );

    if (ok != true || ctrl.text.trim().isEmpty) return;
    final r = NlpService.parse(ctrl.text);
    final amount = r.amount;
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没识别出金额，请写清楚数字和单位（120块）')),
      );
      return;
    }
    // 分类跟随用户最终选择的收支/账本重新判定
    final category = (type == r.type && ledger == r.ledger)
        ? r.category
        : _fallbackCategory(type, ledger, r.category);

    await DbService.instance.insertTransaction(Transaction(
      id: const Uuid().v4(),
      rawText: ctrl.text.trim(),
      amount: amount,
      category: category,
      ledger: ledger,
      type: type,
    ));
    await _load();
  }

  /// 用户手动改了收支/账本时，给一个合理的兜底分类
  String _fallbackCategory(String type, String ledger, String nlpCategory) {
    if (type == TxType.income) {
      return ledger == Ledger.business ? '店铺收入' : '其他收入';
    }
    return ledger == Ledger.business ? '其他' : nlpCategory;
  }

  Future<void> _delete(Transaction t) async {
    await DbService.instance.deleteTransaction(t.id);
    await _load();
  }

  // ---------- 预算分析（仅月视图有意义） ----------
  ({double spent, double remaining, double projectedOver, double dailyLeft})
      _budgetAnalysis() {
    final spent = _summary.expense;
    if (_budget <= 0) {
      return (spent: spent, remaining: 0, projectedOver: 0, dailyLeft: 0);
    }
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dayOfMonth = now.day;
    // 注意：三元两分支须同为 double，否则推断成 num，赋给 double 字段会编译失败
    final double dailyAvg = dayOfMonth > 0 ? spent / dayOfMonth : 0.0;
    final double projected = dailyAvg * daysInMonth;
    final remaining = (_budget - spent).clamp(0, double.infinity).toDouble();
    final daysLeft = (daysInMonth - dayOfMonth + 1).clamp(1, daysInMonth);
    return (
      spent: spent,
      remaining: remaining,
      projectedOver: projected - _budget,
      dailyLeft: remaining / daysLeft,
    );
  }

  // ---------- 每日收支序列（趋势图） ----------
  List<({DateTime day, double expense, double income})> _dailySeries() {
    final exp = <String, double>{};
    final inc = <String, double>{};
    for (final t in _list) {
      final key = DateFormat('yyyy-MM-dd').format(t.occurredAt);
      if (t.isIncome) {
        inc[key] = (inc[key] ?? 0) + t.amount;
      } else {
        exp[key] = (exp[key] ?? 0) + t.amount;
      }
    }
    List<DateTime> days;
    if (_period == 'week') {
      final s = _periodStart();
      days = List.generate(7, (i) => DateTime(s.year, s.month, s.day + i));
    } else {
      final now = DateTime.now();
      final last = DateTime(now.year, now.month + 1, 0).day;
      days = List.generate(last, (i) => DateTime(now.year, now.month, i + 1));
    }
    return days.map((d) {
      final k = DateFormat('yyyy-MM-dd').format(d);
      return (day: d, expense: exp[k] ?? 0.0, income: inc[k] ?? 0.0);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final b = _budgetAnalysis();
    final isSaving = _tab.index == 3;
    return Scaffold(
      appBar: AppBar(
        title: const Text('记账'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: '流水'),
            Tab(text: '汇总'),
            Tab(text: '趋势'),
            Tab(text: '存钱'),
          ],
        ),
        actions: [
          if (!isSaving)
            IconButton(
              icon: const Icon(Icons.savings_outlined),
              onPressed: _setBudget,
              tooltip: '设置预算',
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: isSaving ? '新建存钱目标' : '记一笔',
            onPressed: () {
              if (isSaving) {
                _savingKey.currentState?.addGoal();
              } else {
                _add();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isSaving) ...[
            // 账本切换
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('全部')),
                  ButtonSegment(value: Ledger.personal, label: Text('个人')),
                  ButtonSegment(value: Ledger.business, label: Text('生意')),
                ],
                selected: {_ledger ?? 'all'},
                onSelectionChanged: (s) {
                  setState(() => _ledger = s.first == 'all' ? null : s.first);
                  _load();
                },
              ),
            ),
            // 周期切换
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('本周')),
                  ButtonSegment(value: 'month', label: Text('本月')),
                ],
                selected: {_period},
                onSelectionChanged: (s) {
                  setState(() => _period = s.first);
                  _load();
                },
              ),
            ),
            // 收支结余卡
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SummaryBar(summary: _summary),
            ),
            if (_budget > 0 && _period == 'month')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _BudgetCard(b: b, budget: _budget),
              ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildFlow(),
                _buildSummary(),
                _TrendChart(series: _dailySeries(), period: _period),
                SavingTab(key: _savingKey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 流水 ----------
  Widget _buildFlow() {
    if (_list.isEmpty) {
      return const Center(
          child: Text('还没有记录，点右上 + 记一笔', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: _list.length,
      itemBuilder: (_, i) {
        final t = _list[i];
        final income = t.isIncome;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: (income ? AppTheme.primary : Colors.redAccent).withOpacity(0.15),
            child: Text(
              t.category.isEmpty ? '?' : t.category.substring(0, 1),
              style: TextStyle(
                  color: income ? AppTheme.primaryDark : Colors.redAccent,
                  fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(t.rawText, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: t.ledger == Ledger.business
                    ? Colors.orange.withOpacity(0.15)
                    : Colors.blueGrey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(Ledger.label(t.ledger),
                  style: TextStyle(
                      fontSize: 10,
                      color: t.ledger == Ledger.business
                          ? Colors.orange.shade800
                          : Colors.blueGrey)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${t.category} · ${DateFormat('MM-dd HH:mm').format(t.occurredAt)}',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          ]),
          trailing: Text(
            '${income ? '+' : '-'}¥${t.amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: income ? AppTheme.primary : Colors.red,
                fontWeight: FontWeight.w600),
          ),
          onLongPress: () => _delete(t),
        );
      },
    );
  }

  // ---------- 汇总 ----------
  Widget _buildSummary() {
    final total = _summary.expense;
    if (_categorySum.isEmpty) {
      return const Center(child: Text('本期还没有支出记录', style: TextStyle(color: Colors.grey)));
    }
    final entries = _categorySum.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        SizedBox(
          height: 200,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: entries.asMap().entries.map((e) {
              final v = e.value.value;
              final pct = total == 0 ? '0' : (v / total * 100).toStringAsFixed(1);
              return PieChartSectionData(
                color: AppTheme.categoryColors[e.key % AppTheme.categoryColors.length],
                value: v,
                title: '$pct%',
                radius: 60,
                titleStyle: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              );
            }).toList(),
          )),
        ),
        const SizedBox(height: 16),
        ...entries.asMap().entries.map((e) {
          final k = e.value.key;
          final v = e.value.value;
          return ListTile(
            dense: true,
            leading: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  color: AppTheme.categoryColors[e.key % AppTheme.categoryColors.length],
                  shape: BoxShape.circle),
            ),
            title: Text(k),
            trailing: Text('¥${v.toStringAsFixed(2)}'),
          );
        }),
      ]),
    );
  }
}

/// 收入 / 支出 / 结余
class _SummaryBar extends StatelessWidget {
  final ({double income, double expense, double balance}) summary;
  const _SummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final positive = summary.balance >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        _cell('收入', summary.income, AppTheme.primary),
        _divider(),
        _cell('支出', summary.expense, Colors.redAccent),
        _divider(),
        _cell('结余', summary.balance, positive ? AppTheme.primaryDark : Colors.red,
            prefix: positive ? '' : '-', abs: true),
      ]),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: Colors.grey.shade200);

  Widget _cell(String label, double v, Color color,
      {String prefix = '', bool abs = false}) {
    final shown = abs ? v.abs() : v;
    return Expanded(
      child: Column(children: [
        Text('$prefix¥${shown.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final ({double spent, double remaining, double projectedOver, double dailyLeft}) b;
  final double budget;
  const _BudgetCard({required this.b, required this.budget});

  @override
  Widget build(BuildContext context) {
    final pct = budget <= 0 ? 0.0 : (b.spent / budget).clamp(0.0, 1.0);
    final over = b.projectedOver > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: over ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('月度预算 ¥${budget.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('已花 ¥${b.spent.toStringAsFixed(0)}',
              style: TextStyle(color: over ? Colors.red : Colors.grey)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: over ? Colors.red : AppTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (over)
          Text(
            '⚠️ 按当前速度，月底预计超支 ¥${b.projectedOver.toStringAsFixed(0)}，建议日均控制在 ¥${b.dailyLeft.toStringAsFixed(0)} 内',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          )
        else
          Text(
            '剩余 ¥${b.remaining.toStringAsFixed(0)} · 日均可花 ¥${b.dailyLeft.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
      ]),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<({DateTime day, double expense, double income})> series;
  final String period;
  const _TrendChart({required this.series, required this.period});

  @override
  Widget build(BuildContext context) {
    if (series.every((e) => e.expense == 0 && e.income == 0)) {
      return const Center(child: Text('本期还没有收支记录', style: TextStyle(color: Colors.grey)));
    }
    double maxV = 0;
    for (final e in series) {
      if (e.expense > maxV) maxV = e.expense;
      if (e.income > maxV) maxV = e.income;
    }
    final maxY = maxV * 1.2;
    final barW = period == 'month' ? 3.0 : 8.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(AppTheme.primary, '收入'),
            const SizedBox(width: 16),
            _legend(Colors.redAccent, '支出'),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BarChart(BarChartData(
              maxY: maxY,
              barGroups: series.asMap().entries.map((e) {
                return BarChartGroupData(x: e.key, barsSpace: 2, barRods: [
                  BarChartRodData(
                    toY: e.value.income,
                    color: AppTheme.primary,
                    width: barW,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  BarChartRodData(
                    toY: e.value.expense,
                    color: Colors.redAccent,
                    width: barW,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ]);
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= series.length) return const SizedBox.shrink();
                      final d = series[i].day;
                      if (period == 'month' && d.day % 5 != 0 && d.day != 1) {
                        return const SizedBox.shrink();
                      }
                      final label = period == 'week'
                          ? ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1]
                          : '${d.day}';
                      return Text(label, style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            )),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
}
