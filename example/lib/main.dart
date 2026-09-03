import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:trial_gate/trial_gate.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrialGate 测试',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _deviceId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getDeviceId();
  }

  Future<void> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceId = androidInfo.id;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _deviceId = 'test_device_001';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ====== 配置区 ======
    final config = TrialGateConfig(
      appId: 'hs5_player',
      serverUrl: 'https://pay.5773574.xyz',
      apiKey: 'pk_c4b18ae00a354f27bb491fa1116fc2cb',
      secretKey: 'your_secret_key_here',  // ← 替换为你的密钥
      deviceId: _deviceId,
      amount: 19.90,
      productName: 'HS5车机播放器',
      trialDuration: 300,       // 正式环境：5分钟 = 300秒
      debugDuration: 10,        // 测试用：10秒（正式上线删掉这行）
      offlineCacheDays: 7,
    );

    return TrialGateWidget(
      config: config,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TrialGate 测试'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                '模拟 App 主界面',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '设备ID: $_deviceId',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '试用期间可正常使用此界面\n'
                  '10秒后（测试模式）将锁定\n'
                  '付费后永久解锁',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // 模拟其他操作
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App 功能正常使用中...')),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
