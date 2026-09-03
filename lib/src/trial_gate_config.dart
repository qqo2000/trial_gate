/// TrialGate 配置类
class TrialGateConfig {
  /// App 唯一标识，如 'hs5_player'、'nuoyuan_music'
  final String appId;

  /// 服务器基础 URL，如 'https://pay.5773574.xyz'
  final String serverUrl;

  /// 商户 API Key（pk_ 前缀）
  final String apiKey;

  /// HMAC 验签密钥（与后端一致，不要公开仓库泄露）
  final String secretKey;

  /// 首次试用时长（秒），默认 300 = 5分钟
  final int trialDuration;

  /// 锁死后重新验证的试用时长（秒），默认 60 = 1分钟
  final int recheckDuration;

  /// 调试用首次试用时长（秒），不为 null 时覆盖 trialDuration
  final int? debugDuration;

  /// 调试用重新验证时长（秒），不为 null 时覆盖 recheckDuration
  final int? debugRecheckDuration;

  /// 付费金额（元）
  final double amount;

  /// 商品名称（显示在付款页）
  final String productName;

  /// 离线缓存有效期（天），默认 7 天
  final int offlineCacheDays;

  /// 轮询间隔（秒），默认 2 秒
  final int pollInterval;

  /// 设备唯一标识（Android ID）
  final String deviceId;

  const TrialGateConfig({
    required this.appId,
    required this.serverUrl,
    required this.apiKey,
    required this.secretKey,
    required this.deviceId,
    this.trialDuration = 300,
    this.recheckDuration = 60,
    this.debugDuration,
    this.debugRecheckDuration,
    this.amount = 19.90,
    this.productName = 'App激活',
    this.offlineCacheDays = 7,
    this.pollInterval = 2,
  });

  /// 实际首次试用时长（debugDuration 优先）
  int get effectiveTrialDuration => debugDuration ?? trialDuration;

  /// 实际重新验证时长（debugRecheckDuration 优先）
  int get effectiveRecheckDuration => debugRecheckDuration ?? recheckDuration;

  /// 离线缓存有效期（毫秒）
  int get offlineCacheMs => offlineCacheDays * 24 * 60 * 60 * 1000;
}
