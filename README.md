---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '93cdd24d-71a1-4135-9ab6-c2d2df5d163a'
  PropagateID: '93cdd24d-71a1-4135-9ab6-c2d2df5d163a'
  ReservedCode1: 'e7a9a67f-db1a-4d8b-b6c2-cc8b11b3f0dd'
  ReservedCode2: 'e7a9a67f-db1a-4d8b-b6c2-cc8b11b3f0dd'
---

# TrialGate

Flutter App 试用授权模块 — 5分钟试用倒计时 + 付费永久激活 + 离线缓存 + 服务器验签。

## 功能

- 每次登录后限时试用（默认5分钟），到期完全锁死
- 关闭 App 重新打开重新计时（不持久化试用进度）
- 付费后永久授权，同一设备同一 App 不再弹窗
- 服务器 HMAC-SHA256 签名验证，防伪造响应
- 离线缓存（默认7天），已激活设备断网也可使用
- App 内 WebView 弹窗付费，无需注册
- 多 App 独立计费，通过 appId 区分

## 依赖后端

需要配合 [payc](https://github.com/qqo2000/payc) 支付系统后端使用。

## 用法

```yaml
# pubspec.yaml
dependencies:
  trial_gate:
    git:
      url: https://github.com/qqo2000/trial_gate.git
      ref: main
```

```dart
import 'package:trial_gate/trial_gate.dart';

final config = TrialGateConfig(
  appId: 'hs5_player',
  serverUrl: 'https://pay.5773574.xyz',
  apiKey: 'pk_xxx',
  secretKey: 'your_secret_key',
  deviceId: androidId,
  amount: 19.90,
  productName: 'HS5车机播放器',
);

return TrialGateWidget(
  config: config,
  child: YourApp(),
);
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| appId | App 唯一标识 | 必填 |
| serverUrl | 后端地址 | 必填 |
| apiKey | 商户 API Key | 必填 |
| secretKey | HMAC 验签密钥 | 必填 |
| deviceId | 设备唯一标识（Android ID） | 必填 |
| trialDuration | 试用时长（秒） | 300 |
| debugDuration | 调试用时长（秒），覆盖 trialDuration | null |
| amount | 付费金额 | 19.90 |
| productName | 商品名称 | 'App激活' |
| offlineCacheDays | 离线缓存天数 | 7 |
| pollInterval | 轮询间隔（秒） | 2 |

## 后端 API

| 接口 | 方法 | 说明 |
|------|------|------|
| /api/license/check | GET | 查询授权状态（带签名） |
| /api/license/create | POST | 创建付费订单 |
| /api/license/status | GET | 轮询订单状态 |
| /api/license/reset | POST | 重置许可证（测试用） |

> AI生成