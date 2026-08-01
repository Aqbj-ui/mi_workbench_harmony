// NLP 简易服务：本地关键词匹配，实现"输入一句话自动记账"
// 自动识别：金额 + 收/支方向 + 账本（个人/生意）+ 分类
// 完全离线，不依赖任何云端 API。
import '../models/transaction.dart';

class NlpService {
  // ============ 个人支出分类 ============
  static const Map<String, List<String>> _personalExpense = {
    '水果': ['水果', '榴莲', '苹果', '香蕉', '橙子', '西瓜', '葡萄', '芒果', '草莓', '梨', '桃'],
    '餐饮': ['饭', '吃', '外卖', '餐厅', '奶茶', '咖啡', '饮料', '早餐', '午餐', '晚餐', '宵夜', '麦当劳', '肯德基', '星巴克', '喜茶', '蜜雪'],
    '交通': ['打车', '滴滴', '出租', '公交', '地铁', '高铁', '火车', '飞机', '机票', '油费', '加油', '停车'],
    '购物': ['买', '购物', '淘宝', '京东', '拼多多', '衣服', '鞋子', '包', '化妆品', '超市', '商场'],
    '娱乐': ['电影', '游戏', 'KTV', '唱歌', '酒吧', '景点', '门票', '演唱会'],
    '生活': ['水费', '电费', '燃气', '房租', '物业', '话费', '网费', '宽带', '理发', '美容', '快递'],
    '医疗': ['药', '看病', '医院', '体检', '挂号'],
    '人情': ['随礼', '份子钱', '孝敬', '给爸妈', '给家里'],
  };

  // ============ 个人收入分类 ============
  static const Map<String, List<String>> _personalIncome = {
    '工资': ['工资', '薪水', '发薪', '月薪', '年终奖', '奖金', '提成'],
    '其他收入': ['红包', '利息', '分红', '返现', '返利', '退款', '转入', '收入', '兼职'],
  };

  // ============ 生意支出分类（跨境电商） ============
  static const Map<String, List<String>> _bizExpense = {
    '广告推广': ['广告', '推广', '投流', '站外', '红人', '测评', 'deals', 'cpc', 'ppc', '直通车'],
    '物流运费': ['物流', '头程', '尾程', '运费', '海运', '空运', '快递费', '派送', '清关', '关税', '报关'],
    '采购进货': ['采购', '进货', '拿货', '工厂', '打样', '样品', '备货', '供应商'],
    '平台费用': ['平台佣金', '平台费', '店铺租金', '月租', 'fba', '亚马逊', '速卖通', 'shopee', 'lazada', 'temu', 'ebay', '佣金'],
    '仓储': ['仓储', '仓库', '海外仓', '托管费'],
    '包材': ['包材', '纸箱', '贴纸', '标签', '气泡袋', '包装'],
    '人工外包': ['外包', '客服', '美工', '运营工资', '兼职工资', '员工'],
    '软件工具': ['软件', '订阅', 'erp', 'saas', '会员费', '工具费', '服务器'],
  };

  // ============ 生意收入分类 ============
  static const Map<String, List<String>> _bizIncome = {
    '店铺收入': ['回款', '货款', '营业额', '销售额', '结算', '订单收入', '平台打款', '放款', '卖了'],
  };

  // 收入信号词
  static const List<String> _incomeWords = [
    '工资', '薪水', '发薪', '月薪', '年终奖', '奖金', '提成', '回款', '收款', '入账', '到账',
    '退款', '返现', '返利', '货款', '结算', '分红', '利息', '红包', '转入', '收入',
    '赚了', '卖了', '营业额', '销售额', '平台打款', '放款', '进账',
  ];

  // 强支出信号词（压制误判，如"给客户退款"其实是支出）
  static const List<String> _expenseWords = [
    '花了', '花费', '付了', '支付', '支出', '消费', '买', '充值', '缴', '交了', '扣了', '赔', '罚',
  ];

  // 生意场景信号词（决定账本归属）
  static const List<String> _bizWords = [
    '店铺', '客户', '订单', '平台', '跨境', '亚马逊', '速卖通', 'shopee', 'lazada', 'temu', 'ebay',
    '发货', '备货', '供应商', '工厂', '头程', '海外仓', 'fba', '广告', '投流', '清关', '关税', '报关',
  ];

  /// 主入口：传入原始文本，返回 (分类, 金额, 收支类型, 账本)
  /// 示例:
  ///   "今天买了个榴莲120块"      -> (水果, 120, expense, personal)
  ///   "亚马逊回款8000"           -> (店铺收入, 8000, income, business)
  ///   "投广告花了500"            -> (广告推广, 500, expense, business)
  static ({String category, double amount, String type, String ledger}) parse(String input) {
    final amount = _extractAmount(input);
    final isIncome = _judgeIncome(input);
    final isBiz = _judgeBusiness(input, isIncome);

    final String category;
    if (isIncome) {
      category = isBiz
          ? (_match(_bizIncome, input) ?? '店铺收入')
          : (_match(_personalIncome, input) ?? '其他收入');
    } else {
      category = isBiz
          ? (_match(_bizExpense, input) ?? '其他')
          : (_match(_personalExpense, input) ?? '其他');
    }

    return (
      category: category,
      amount: amount,
      type: isIncome ? TxType.income : TxType.expense,
      ledger: isBiz ? Ledger.business : Ledger.personal,
    );
  }

  /// 判断收入：命中收入词，且没有更强的支出信号
  static bool _judgeIncome(String input) {
    final hitIncome = _incomeWords.any((w) => _has(input, w));
    if (!hitIncome) return false;
    // "给客户退款500" / "买东西花了" 这类含支出动词的，按支出处理
    final hitExpense = _expenseWords.any((w) => _has(input, w));
    if (!hitExpense) return true;
    // 两边都命中时，比较最靠前出现的词（谁先出现听谁的）
    final iIncome = _firstIndex(input, _incomeWords);
    final iExpense = _firstIndex(input, _expenseWords);
    return iIncome >= 0 && (iExpense < 0 || iIncome < iExpense);
  }

  /// 判断是否生意账本
  static bool _judgeBusiness(String input, bool isIncome) {
    if (_bizWords.any((w) => _has(input, w))) return true;
    final rules = isIncome ? _bizIncome : _bizExpense;
    return _match(rules, input) != null;
  }

  /// 在规则表中按"关键词更长者优先"匹配分类
  static String? _match(Map<String, List<String>> rules, String input) {
    final pairs = rules.entries
        .expand((e) => e.value.map((k) => MapEntry(k, e.key)))
        .toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in pairs) {
      if (_has(input, e.key)) return e.value;
    }
    return null;
  }

  static bool _has(String input, String keyword) =>
      input.toLowerCase().contains(keyword.toLowerCase());

  static int _firstIndex(String input, List<String> words) {
    final lower = input.toLowerCase();
    int best = -1;
    for (final w in words) {
      final i = lower.indexOf(w.toLowerCase());
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }

  static double _extractAmount(String input) {
    // 1) 优先匹配带货币单位的数字："120块" / "8000元" / "¥50"
    final withUnit = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块|元|钱|万|RMB|rmb|¥)');
    final m1 = withUnit.firstMatch(input);
    if (m1 != null) {
      var v = double.tryParse(m1.group(1) ?? '') ?? 0.0;
      if ((m1.group(0) ?? '').contains('万')) v *= 10000; // "1.5万" -> 15000
      return v;
    }
    // 2) 动词后紧跟的数字："花了80" / "回款8000"
    final afterVerb = RegExp(r'(?:花了|花费|支出|消费|付了|回款|收款|到账|入账|赚了)\s*(\d+(?:\.\d+)?)');
    final m2 = afterVerb.firstMatch(input);
    if (m2 != null) return double.tryParse(m2.group(1) ?? '') ?? 0.0;
    // 3) 兜底：取文本中最大的数字（避免"买2个苹果30"取到 2）
    final all = RegExp(r'\d+(?:\.\d+)?').allMatches(input);
    double best = 0;
    for (final m in all) {
      final v = double.tryParse(m.group(0) ?? '') ?? 0;
      if (v > best) best = v;
    }
    return best;
  }
}
