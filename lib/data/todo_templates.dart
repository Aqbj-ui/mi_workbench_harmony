// 跨境电商任务模板库：一键把常用流程铺成待办清单
import '../models/transaction.dart' show Ledger;

/// 单条模板任务
class TodoTemplate {
  final String title;
  final String priority; // urgent / important / normal
  final String tags; // 逗号分隔
  final int offsetDays; // 相对今天的截止天数（0=今天），递进截止
  final String? detail; // 步骤明细（v3 阶段 4：模板库展示用）
  final String? note;

  const TodoTemplate({
    required this.title,
    this.priority = 'normal',
    this.tags = '',
    this.offsetDays = 0,
    this.detail,
    this.note,
  });
}

/// 模板包（一个业务流程）
class TemplatePack {
  final String id;
  final String icon;
  final String name;
  final String desc;
  final String ledger;
  final List<TodoTemplate> items;

  const TemplatePack({
    required this.id,
    required this.icon,
    required this.name,
    required this.desc,
    this.ledger = Ledger.business,
    required this.items,
  });

  int get count => items.length;
}

/// 全部模板包
const List<TemplatePack> kTemplatePacks = [
  // ============ 新品上架 ============
  TemplatePack(
    id: 'launch',
    icon: '🚀',
    name: '新品上架全流程',
    desc: '从选品调研到上架校对，10 步不漏项',
    items: [
      TodoTemplate(title: '竞品调研：TOP10 价格/评分/卖点拆解', priority: 'important', tags: '选品', offsetDays: 1, detail: '拆 3 个核心竞品，记录价格带与差评点'),
      TodoTemplate(title: '核算成本与定价（含头程、平台佣金、退货率）', priority: 'urgent', tags: '选品,财务', offsetDays: 2, detail: '反推最低可售价，保证 30% 毛利'),
      TodoTemplate(title: '联系供应商要样品并确认工艺', priority: 'important', tags: '供应链', offsetDays: 3, detail: '确认工艺与交期，避免大货翻车'),
      TodoTemplate(title: '样品到货验收：尺寸/材质/包装', tags: '供应链', offsetDays: 7, detail: '到货当天核对，不符即退'),
      TodoTemplate(title: '拍摄主图（白底图 + 场景图 + 细节图）', priority: 'important', tags: '素材', offsetDays: 9, detail: '白底图符合平台规范'),
      TodoTemplate(title: '关键词调研并埋词（标题/五点/后台词）', priority: 'important', tags: '运营', offsetDays: 10, detail: '标题/五点/后台词三方覆盖'),
      TodoTemplate(title: '撰写 Listing 文案并母语校对', tags: '运营', offsetDays: 11, detail: '避免中式英语'),
      TodoTemplate(title: '合规检查：标签、成分、认证是否齐全', priority: 'urgent', tags: '合规', offsetDays: 11, detail: '目标国准入资质齐全'),
      TodoTemplate(title: '创建 SKU 并上传资料，检查变体关系', tags: '运营', offsetDays: 12, detail: '检查变体关系'),
      TodoTemplate(title: '上架后自查：图片顺序/价格/库存/物流模板', priority: 'important', tags: '运营', offsetDays: 13, detail: '上线前最后一道关'),
    ],
  ),

  // ============ 备货物流 ============
  TemplatePack(
    id: 'supply',
    icon: '📦',
    name: '备货与头程物流',
    desc: '补货测算到入库上架，卡住断货风险',
    items: [
      TodoTemplate(title: '统计近 30 天日均销量，测算补货数量', priority: 'urgent', tags: '供应链', offsetDays: 0, detail: '可售天数 < 15 天立即补'),
      TodoTemplate(title: '检查在途库存与可售天数，标出断货风险款', priority: 'urgent', tags: '供应链', offsetDays: 0, detail: '重点监控'),
      TodoTemplate(title: '向工厂下采购单并确认交期', priority: 'important', tags: '供应链', offsetDays: 1, detail: '确认交期'),
      TodoTemplate(title: '支付货款定金并留存凭证', tags: '财务', offsetDays: 2, detail: '留存凭证'),
      TodoTemplate(title: '安排验货（外观/数量/贴标）', priority: 'important', tags: '供应链', offsetDays: 10, detail: '外观/数量/贴标'),
      TodoTemplate(title: '订舱头程，确认走空运还是海运', priority: 'important', tags: '物流', offsetDays: 12, detail: '空运快、海运省'),
      TodoTemplate(title: '准备清关资料（发票/装箱单/申报要素）', priority: 'urgent', tags: '物流,合规', offsetDays: 13, detail: '发票/装箱单/申报要素'),
      TodoTemplate(title: '创建入库计划并打印外箱标', tags: '物流', offsetDays: 14, detail: '打印外箱标'),
      TodoTemplate(title: '跟踪在途轨迹，异常及时催件', tags: '物流', offsetDays: 20, detail: '异常及时催件'),
      TodoTemplate(title: '到仓核对上架数量，差异开案件', priority: 'important', tags: '物流', offsetDays: 30, detail: '差异开案件'),
    ],
  ),

  // ============ 运营广告 ============
  TemplatePack(
    id: 'ads',
    icon: '📈',
    name: '每周运营复盘',
    desc: '广告 + Listing 数据一周一盘，别烧冤枉钱',
    items: [
      TodoTemplate(title: '导出上周广告报表，看花费/ACOS/出单', priority: 'important', tags: '广告', offsetDays: 0, detail: '花费/ACOS/出单'),
      TodoTemplate(title: '否掉高花费零转化的搜索词', priority: 'urgent', tags: '广告', offsetDays: 0, detail: '节流第一步'),
      TodoTemplate(title: '给出单好的词提竞价，差的降价', tags: '广告', offsetDays: 1, detail: '好词提竞价/差词降价'),
      TodoTemplate(title: '检查自然排名变化，对比竞品价格', tags: '运营', offsetDays: 1, detail: '对比竞品价格'),
      TodoTemplate(title: '统计转化率与退货率，找异常 SKU', priority: 'important', tags: '运营', offsetDays: 2, detail: '找异常 SKU'),
      TodoTemplate(title: '跟进新增 Review，处理差评', priority: 'urgent', tags: '客服', offsetDays: 2, detail: '先安抚再解决'),
      TodoTemplate(title: '报名下周站内活动/秒杀', tags: '运营', offsetDays: 3, detail: '抢流量位'),
      TodoTemplate(title: '整理本周结论，定下周动作', priority: 'important', tags: '运营', offsetDays: 4, detail: '形成闭环'),
    ],
  ),

  // ============ 财务对账 ============
  TemplatePack(
    id: 'finance',
    icon: '💰',
    name: '月度财务对账',
    desc: '回款、平台费、汇率，一笔都别糊涂',
    items: [
      TodoTemplate(title: '下载平台结算报表，核对回款金额', priority: 'urgent', tags: '财务', offsetDays: 0, detail: '对账起点'),
      TodoTemplate(title: '核对平台佣金/仓储费/长期仓储费', priority: 'important', tags: '财务', offsetDays: 1, detail: '别漏长期仓储费'),
      TodoTemplate(title: '统计本月广告花费并计入成本', tags: '财务', offsetDays: 1, detail: '计入成本'),
      TodoTemplate(title: '核对头程物流账单与报价是否一致', tags: '财务,物流', offsetDays: 2, detail: '报价 vs 实际'),
      TodoTemplate(title: '结算供应商货款尾款', priority: 'important', tags: '财务', offsetDays: 3, detail: '尾款结算'),
      TodoTemplate(title: '登记汇率损益，测算本月真实毛利', priority: 'important', tags: '财务', offsetDays: 4, detail: '含汇率损益'),
      TodoTemplate(title: '整理发票与凭证，准备退税资料', tags: '财务,合规', offsetDays: 5, detail: '退税资料'),
      TodoTemplate(title: '把本月结余转入存钱目标', tags: '财务', offsetDays: 5, note: '对应记账页的存钱计划', detail: '联动记账↔存钱'),
    ],
  ),

  // ============ 食品标签合规 ============
  TemplatePack(
    id: 'compliance',
    icon: '🛡️',
    name: '食品标签合规自查',
    desc: '罐头/食品贴纸上架前的合规清单',
    items: [
      TodoTemplate(title: '核对品名与真实属性是否一致', priority: 'urgent', tags: '合规', offsetDays: 0, detail: '品名不误导'),
      TodoTemplate(title: '配料表按含量递减排序，复核食品添加剂写法', priority: 'urgent', tags: '合规', offsetDays: 0, detail: '递减 + 添加剂写法'),
      TodoTemplate(title: '核对营养成分表数值与单位（含 NRV%）', priority: 'important', tags: '合规', offsetDays: 1, detail: '数值/单位/NRV%'),
      TodoTemplate(title: '检查过敏原提示是否完整标注', priority: 'important', tags: '合规', offsetDays: 1, detail: '过敏原别漏'),
      TodoTemplate(title: '核对净含量、规格字号是否达标', tags: '合规', offsetDays: 2, detail: '字号达标'),
      TodoTemplate(title: '确认生产日期/保质期/贮存条件表述', priority: 'important', tags: '合规', offsetDays: 2, detail: '日期表述规范'),
      TodoTemplate(title: '核对生产者名称地址、许可证号', tags: '合规', offsetDays: 3, detail: '主体信息齐全'),
      TodoTemplate(title: '排查宣称用语（不得涉疗效/绝对化用语）', priority: 'urgent', tags: '合规', offsetDays: 3, detail: '禁疗效/绝对化'),
      TodoTemplate(title: '目标国语言版本翻译校对', tags: '合规', offsetDays: 4, detail: '翻译校对'),
      TodoTemplate(title: '留存合规自查记录与检测报告', tags: '合规', offsetDays: 5, detail: '留痕可查'),
    ],
  ),

  // ============ 旺季备战 ============
  TemplatePack(
    id: 'peak',
    icon: '🎯',
    name: '旺季大促备战',
    desc: '黑五/网一/年终，提前 45 天开跑',
    items: [
      TodoTemplate(title: '锁定主推款，预估旺季销量倍数', priority: 'urgent', tags: '运营', offsetDays: 0, detail: '估销量倍数'),
      TodoTemplate(title: '按预估下单备货，留足头程时间', priority: 'urgent', tags: '供应链', offsetDays: 2, detail: '留足头程'),
      TodoTemplate(title: '确认入仓截止日期，倒排发货计划', priority: 'urgent', tags: '物流', offsetDays: 3, detail: '倒排发货'),
      TodoTemplate(title: '准备促销素材与折扣方案', tags: '素材', offsetDays: 10, detail: '素材+折扣'),
      TodoTemplate(title: '报名大促活动，检查资格与库存要求', priority: 'important', tags: '运营', offsetDays: 12, detail: '查资格/库存'),
      TodoTemplate(title: '提前加预算蓄水广告，抢排名', priority: 'important', tags: '广告', offsetDays: 20, detail: '蓄水抢排名'),
      TodoTemplate(title: '设置价格与优惠券，核对不亏本', priority: 'urgent', tags: '财务', offsetDays: 30, detail: '不亏本'),
      TodoTemplate(title: '大促期间盯库存与广告，每日复盘', priority: 'urgent', tags: '运营', offsetDays: 40, detail: '每日复盘'),
      TodoTemplate(title: '大促后清尾货、复盘 ROI', tags: '运营', offsetDays: 45, detail: '复盘 ROI'),
    ],
  ),

  // ============ 客诉售后 ============
  TemplatePack(
    id: 'service',
    icon: '🙋',
    name: '客诉处理流程',
    desc: '一单客诉的标准动作，别漏跟进',
    items: [
      TodoTemplate(title: '24 小时内首次回复客户', priority: 'urgent', tags: '客服', offsetDays: 0, detail: '首响时效'),
      TodoTemplate(title: '核实订单与物流轨迹，判断责任方', priority: 'urgent', tags: '客服', offsetDays: 0, detail: '判责'),
      TodoTemplate(title: '给出方案：补发/退款/折扣三选一', priority: 'important', tags: '客服', offsetDays: 1, detail: '三选一'),
      TodoTemplate(title: '执行方案并留存沟通记录', tags: '客服', offsetDays: 2, detail: '留痕'),
      TodoTemplate(title: '回访确认客户满意，争取修改差评', tags: '客服', offsetDays: 5, detail: '改差评'),
      TodoTemplate(title: '归因分析：是产品、包装还是物流问题', priority: 'important', tags: '运营', offsetDays: 6, detail: '归因'),
      TodoTemplate(title: '把改进点同步给供应商', tags: '供应链', offsetDays: 7, detail: '同步供应商'),
    ],
  ),

  // ============ 个人 ============
  TemplatePack(
    id: 'personal',
    icon: '🏠',
    name: '个人周计划',
    desc: '生意之外，把自己的事也安排上',
    ledger: Ledger.personal,
    items: [
      TodoTemplate(title: '本周运动 3 次', priority: 'important', tags: '健康', offsetDays: 6, detail: '保持手感'),
      TodoTemplate(title: '记录体重并对照目标', tags: '健康', offsetDays: 0, detail: '看趋势'),
      TodoTemplate(title: '检查存钱目标进度，补上本周存款', priority: 'important', tags: '理财', offsetDays: 2, detail: '雷打不动'),
      TodoTemplate(title: '陪家人吃一次饭', tags: '家庭', offsetDays: 5, detail: '充电'),
      TodoTemplate(title: '读书或学习 2 小时', tags: '成长', offsetDays: 6, detail: '长期主义'),
      TodoTemplate(title: '周末复盘：这周做成了什么', tags: '成长', offsetDays: 6, detail: '复盘'),
    ],
  ),
];
