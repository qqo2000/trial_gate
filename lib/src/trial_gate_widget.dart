import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'trial_gate_controller.dart';
import 'trial_gate_config.dart';

/// TrialGate Widget — 包裹在 App 根 Widget 外层
///
/// 用法：
/// ```dart
/// TrialGateWidget(
///   config: config,
///   child: YourApp(),
/// )
/// ```
class TrialGateWidget extends StatefulWidget {
  final TrialGateConfig config;
  final Widget child;

  const TrialGateWidget({
    super.key,
    required this.config,
    required this.child,
  });

  @override
  State<TrialGateWidget> createState() => _TrialGateWidgetState();
}

class _TrialGateWidgetState extends State<TrialGateWidget> {
  late TrialGateController _controller;
  TrialGateState? _state;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _controller = TrialGateController(widget.config);
    _sub = _controller.stateStream.listen((state) {
      setState(() => _state = state);
    });
    _controller.start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 底层：App 正常内容
        widget.child,

        // 覆盖层：根据状态显示不同 UI
        if (_state != null) ..._buildOverlay(_state!),
      ],
    );
  }

  List<Widget> _buildOverlay(TrialGateState state) {
    switch (state.state) {
      case LicenseState.checking:
        return [
          Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 16),
                  Text('正在验证授权...', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ];

      case LicenseState.activated:
        return []; // 已激活，无覆盖层

      case LicenseState.trial:
        // 试用中：顶部显示剩余时间条
        return [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TrialBanner(
              remainingSeconds: state.remainingSeconds,
              totalSeconds: widget.config.effectiveTrialDuration,
            ),
          ),
        ];

      case LicenseState.locked:
        return [
          _buildLockedOverlay(),
        ];

      case LicenseState.creatingOrder:
        return [
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('正在创建订单...', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
        ];

      case LicenseState.waitingPayment:
        if (state.payUrl != null) {
          return [
            _buildPaymentWebView(state.payUrl!, state.orderId),
          ];
        }
        return [];

      case LicenseState.paymentSuccess:
        return [
          _buildSuccessOverlay(),
        ];

      case LicenseState.error:
        return [
          _buildErrorOverlay(state.errorMessage ?? '未知错误'),
        ];
    }
  }

  /// 锁死覆盖层
  Widget _buildLockedOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock, size: 64, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                '试用时间已到',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.config.productName} 试用结束\n付费 ${widget.config.amount.toStringAsFixed(2)} 元即可永久使用',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _controller.createPaymentOrder(),
                  child: Text('立即付费 ${widget.config.amount.toStringAsFixed(2)} 元'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // 重新检查授权（可能已在其他设备付费）
                  _controller.start();
                },
                child: const Text(
                  '我已付费，重新验证',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 付费 WebView（全屏覆盖）
  Widget _buildPaymentWebView(String payUrl, String? orderId) {
    return PaymentWebView(
      url: payUrl,
      onPaymentDetected: () {
        _controller.confirmActivated();
      },
      onClose: () {
        // 关闭 WebView，回到锁死状态
        setState(() {
          _state = TrialGateState(state: LicenseState.locked);
        });
      },
    );
  }

  /// 付款成功覆盖层
  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              '激活成功！',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.config.productName} 已永久授权',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  _state = TrialGateState(state: LicenseState.activated);
                });
              },
              child: const Text('开始使用'),
            ),
          ],
        ),
      ),
    );
  }

  /// 错误覆盖层
  Widget _buildErrorOverlay(String message) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _controller.start(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 试用倒计时横幅
class _TrialBanner extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const _TrialBanner({
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final progress = 1.0 - (remainingSeconds / totalSeconds);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.withOpacity(0.9),
              Colors.orange.withOpacity(0.7),
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              '试用剩余 ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 付费 WebView 全屏组件
class PaymentWebView extends StatefulWidget {
  final String url;
  final VoidCallback onPaymentDetected;
  final VoidCallback onClose;

  const PaymentWebView({
    super.key,
    required this.url,
    required this.onPaymentDetected,
    required this.onClose,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          // 监听页面变化，检测支付成功
          onPageFinished: (url) {
            // 付款页支付成功后会显示"支付成功"文字
            // 也可以通过 JS 通道检测
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            Container(
              height: 48,
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: widget.onClose,
                  ),
                  const Expanded(
                    child: Text(
                      '扫码支付',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 48), // 平衡布局
                ],
              ),
            ),
            // WebView
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
