import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'trial_gate_config.dart';

/// 授权状态
enum LicenseState {
  /// 正在检查中
  checking,
  /// 已激活（永久授权）
  activated,
  /// 试用中
  trial,
  /// 试用到期，已锁死
  locked,
  /// 正在创建订单
  creatingOrder,
  /// 等待付款
  waitingPayment,
  /// 付款成功，已激活
  paymentSuccess,
  /// 网络错误
  error,
}

/// 控制器状态数据
class TrialGateState {
  final LicenseState state;
  final int remainingSeconds;
  final String? errorMessage;
  final String? payUrl;
  final String? orderId;

  TrialGateState({
    required this.state,
    this.remainingSeconds = 0,
    this.errorMessage,
    this.payUrl,
    this.orderId,
  });

  TrialGateState copyWith({
    LicenseState? state,
    int? remainingSeconds,
    String? errorMessage,
    String? payUrl,
    String? orderId,
  }) {
    return TrialGateState(
      state: state ?? this.state,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      errorMessage: errorMessage,
      payUrl: payUrl ?? this.payUrl,
      orderId: orderId ?? this.orderId,
    );
  }
}

/// TrialGate 控制器
///
/// 用法：
/// ```dart
/// final controller = TrialGateController(config);
/// controller.stateStream.listen((state) { ... });
/// await controller.start();
/// ```
class TrialGateController {
  final TrialGateConfig config;

  // 状态流
  final _stateController = StreamController<TrialGateState>.broadcast();
  Stream<TrialGateState> get stateStream => _stateController.stream;

  TrialGateState _currentState = TrialGateState(state: LicenseState.checking);
  TrialGateState get currentState => _currentState;

  Timer? _countdownTimer;
  Timer? _pollTimer;
  SharedPreferences? _prefs;

  // 离线缓存 key
  static const _cacheKeyPrefix = 'trial_gate_license_';

  TrialGateController(this.config);

  /// 启动授权检查流程
  Future<void> start() async {
    _prefs = await SharedPreferences.getInstance();
    _emitState(TrialGateState(state: LicenseState.checking));

    try {
      // 1. 先查服务器授权状态
      final isActivated = await _checkLicense();

      if (isActivated) {
        // 已激活，保存缓存
        _saveCache();
        _emitState(TrialGateState(state: LicenseState.activated));
        return;
      }

      // 2. 服务器未激活，检查离线缓存
      if (_isCacheValid()) {
        // 有有效缓存，说明之前激活过（离线场景）
        _emitState(TrialGateState(state: LicenseState.activated));
        return;
      }

      // 3. 未激活，开始试用倒计时
      _startTrial();
    } catch (e) {
      // 网络错误，检查离线缓存
      if (_isCacheValid()) {
        _emitState(TrialGateState(state: LicenseState.activated));
        return;
      }
      // 无缓存，网络错误也给试用
      _startTrial();
    }
  }

  /// 查询服务器授权状态（带验签）
  Future<bool> _checkLicense() async {
    final url = Uri.parse(
      '${config.serverUrl}/api/license/check'
      '?appId=${config.appId}'
      '&deviceId=${config.deviceId}'
      '&secretKey=${Uri.encodeComponent(config.secretKey)}',
    );

    final resp = await http.get(url).timeout(
      const Duration(seconds: 10),
    );

    if (resp.statusCode != 200) {
      throw Exception('服务器返回 ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);

    // 验签：用同样密钥本地计算签名，对比服务器返回的签名
    final activated = data['activated'] == true;
    final timestamp = data['timestamp'] as int;
    final serverSign = data['sign'] as String?;

    if (serverSign == null) {
      throw Exception('服务器未返回签名');
    }

    // 本地计算签名
    final signData = '${config.appId}|${config.deviceId}|$activated|$timestamp';
    final localSign = _hmacSign(signData, config.secretKey);

    if (localSign != serverSign) {
      // 签名不匹配，不信任结果，当作未激活
      return false;
    }

    return activated;
  }

  /// HMAC-SHA256 签名（与后端 crypto.js hmacSign 一致）
  String _hmacSign(String data, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  /// 开始试用倒计时（使用配置的试用时长）
  void _startTrial() {
    _startTrialWithDuration(config.effectiveTrialDuration);
  }

  /// 锁死后重新验证授权（只给1分钟试用，防止无限续用）
  Future<void> recheckLicense() async {
    _emitState(TrialGateState(state: LicenseState.checking));

    try {
      final isActivated = await _checkLicense();

      if (isActivated) {
        _saveCache();
        _emitState(TrialGateState(state: LicenseState.activated));
        return;
      }

      // 未激活，只给1分钟（60秒）
      _startTrialWithDuration(60);
    } catch (e) {
      // 网络错误，也只给1分钟
      _startTrialWithDuration(60);
    }
  }

  /// 指定时长的试用倒计时
  void _startTrialWithDuration(int durationSeconds) {
    int remaining = durationSeconds;
    _emitState(TrialGateState(
      state: LicenseState.trial,
      remainingSeconds: remaining,
    ));

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        _emitState(TrialGateState(
          state: LicenseState.locked,
          remainingSeconds: 0,
        ));
      } else {
        _emitState(TrialGateState(
          state: LicenseState.trial,
          remainingSeconds: remaining,
        ));
      }
    });
  }

  /// 创建付费订单并弹出 WebView
  Future<void> createPaymentOrder() async {
    _emitState(TrialGateState(state: LicenseState.creatingOrder));

    try {
      final url = Uri.parse('${config.serverUrl}/api/license/create');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apiKey': config.apiKey,
          'appId': config.appId,
          'deviceId': config.deviceId,
          'amount': config.amount,
          'productName': config.productName,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body);

      if (data['error'] != null) {
        _emitState(TrialGateState(
          state: LicenseState.error,
          errorMessage: data['error'],
        ));
        return;
      }

      final orderId = data['orderId'] as String;
      final payUrl = data['payUrl'] as String;
      final pollToken = data['pollToken'] as String?;

      // 进入等待付款状态，返回付款页 URL
      _emitState(TrialGateState(
        state: LicenseState.waitingPayment,
        payUrl: payUrl,
        orderId: orderId,
      ));

      // 开始轮询订单状态
      _startPolling(orderId, pollToken);
    } catch (e) {
      _emitState(TrialGateState(
        state: LicenseState.error,
        errorMessage: '创建订单失败: $e',
      ));
    }
  }

  /// 轮询订单状态
  void _startPolling(String orderId, String? pollToken) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: config.pollInterval),
      (timer) async {
        try {
          final url = Uri.parse(
            '${config.serverUrl}/api/license/status'
            '?orderId=$orderId'
            '${pollToken != null ? '&pollToken=$pollToken' : ''}',
          );
          final resp = await http.get(url).timeout(
            const Duration(seconds: 10),
          );
          final data = jsonDecode(resp.body);

          if (data['activated'] == true || data['status'] == 'completed') {
            timer.cancel();
            _saveCache();
            _emitState(TrialGateState(state: LicenseState.paymentSuccess));
          } else if (data['status'] == 'expired') {
            timer.cancel();
            _emitState(TrialGateState(
              state: LicenseState.error,
              errorMessage: '订单已过期，请重新付费',
            ));
          }
        } catch (e) {
          // 网络错误，继续轮询
        }
      },
    );
  }

  /// 付款成功后，外部调用此方法确认激活
  void confirmActivated() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _saveCache();
    _emitState(TrialGateState(state: LicenseState.activated));
  }

  /// 离线缓存相关
  String get _cacheKey => '$_cacheKeyPrefix${config.appId}_${config.deviceId}';

  void _saveCache() {
    _prefs?.setInt(_cacheKey, DateTime.now().millisecondsSinceEpoch);
  }

  bool _isCacheValid() {
    final cached = _prefs?.getInt(_cacheKey);
    if (cached == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - cached;
    return age < config.offlineCacheMs;
  }

  void _emitState(TrialGateState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// 释放资源
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _stateController.close();
  }
}
