import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'storage.dart';
import 'utils.dart';

/// 根据小时计算时段加成系数
double getTimeSlotMultiplier(int hour) {
  switch (hour) {
    case 0: // 午夜
      return 0.3;
    case 1:
      return 0.2;
    case 2:
      return 0.1;
    case 3:
      return 0.1;
    case 4:
      return 0.2;
    case 5:
      return 0.4;
    case 6: // 清晨
      return 0.8;
    case 7:
      return 1.2;
    case 8:
      return 1.5;
    case 9:
      return 1.4;
    case 10:
      return 1.3;
    case 11:
      return 1.2;
    case 12: // 中午
      return 1.0;
    case 13:
      return 0.9;
    case 14:
      return 0.8;
    case 15:
      return 0.9;
    case 16:
      return 1.1;
    case 17:
      return 1.3;
    case 18: // 傍晚
      return 1.8;
    case 19:
      return 1.6;
    case 20:
      return 1.4;
    case 21:
      return 1.2;
    case 22:
      return 0.9;
    case 23: // 深夜
      return 0.6;
    default:
      return 1.0;
  }
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // 第一行：确保Flutter绑定在后台Isolate中可用
  WidgetsFlutterBinding.ensureInitialized();

  // 第二行：确保所有插件的后台实现能够被正确"唤醒"
  DartPluginRegistrant.ensureInitialized();

  // 第三行：初始化我们自己的存储服务
  await StorageService().init();

  debugPrint("onStart函数被调用！Service ID: ${service.hashCode}");

  // 创建存储服务实例
  final storage = StorageService();
  await storage.init();

  // 创建周期性心跳定时器
  Timer? periodicTimer;

  // 设置服务停止监听器
  service.on('stop').listen((event) {
    debugPrint("接收到'stop'事件！正在停止服务...");
    periodicTimer?.cancel();
    service.stopSelf();
  });

  // 创建每小时执行一次的周期性定时器
  periodicTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
    debugPrint("心跳检查触发！Time: ${DateTime.now()}");
    try {
      // 获取上次互动时间
      DateTime? lastInteractionTime = await storage.getLastInteractionTime();
      if (lastInteractionTime == null) {
        debugPrint("没有找到上次互动时间，跳过概率检查");
        return;
      }

      // 计算时间差（小时）
      DateTime now = DateTime.now();
      double timeDiff = now.difference(lastInteractionTime).inHours.toDouble();

      // 实现概率函数
      double triggerProbability = 0.0;

      // 生产环境概率判断逻辑
      if (timeDiff < 12) {
        triggerProbability = 0.0;
      } else if (timeDiff < 24) {
        // 12-24小时，概率从0%递增到50%
        triggerProbability = (timeDiff - 12) / 12 * 0.5;
      } else if (timeDiff < 48) {
        // 24-48小时，概率从50%递增到100%
        triggerProbability = 0.5 + (timeDiff - 24) / 24 * 0.5;
      } else {
        // 48小时以上，100%触发
        triggerProbability = 1.0;
      }

      // 获取当前小时并计算时段加成
      final currentHour = DateTime.now().hour;
      final multiplier = getTimeSlotMultiplier(currentHour);
      final finalProbability = triggerProbability * multiplier;

      debugPrint(
          "生物钟计算 - 基础概率: ${triggerProbability.toStringAsFixed(3)}, 时段加成: ${multiplier.toStringAsFixed(2)}, 最终概率: ${finalProbability.toStringAsFixed(3)}");

      if (Random().nextDouble() < finalProbability) {
        // 概率触发成功
        await sendGhostCommand();

        // 确保计数器增加的逻辑存在
        final storage = StorageService();
        await storage.init();
        int currentCount = await storage.getLongingCounter();
        await storage.setLongingCounter(currentCount + 1);

        debugPrint("生物钟模式：概率触发成功！计数器现在是: ${currentCount + 1}");
      } else {
        debugPrint("生物钟模式：概率检查未通过。");
      }
    } catch (e) {
      debugPrint("概率检查过程中发生错误: $e");
    }
  });

  debugPrint("后台服务已启动，生物钟概率递进常规模式已初始化");
}

/// 发送幽灵指令的网络请求实现
Future<void> sendGhostCommand() async {
  try {
    // 获取存储服务实例
    final storage = StorageService();
    await storage.init();

    // 获取API配置
    List<Config> configs = await storage.getApiConfigs();
    if (configs.isEmpty) {
      debugPrint("没有可用的API配置，跳过幽灵指令发送");
      return;
    }

    Config config = configs[0]; // 使用第一个配置

    // 创建Dio实例
    Dio dio = Dio();

    // 设置请求头
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    // 构建请求体
    Map<String, dynamic> requestBody = {
      'model': config.model,
      'messages': [
        {'role': 'user', 'content': 'himari_ping'}
      ],
      'stream': false,
    };

    // 添加可选参数
    if (config.temperature != null && config.temperature!.isNotEmpty) {
      requestBody['temperature'] = double.tryParse(config.temperature!);
    }
    if (config.maxTokens != null && config.maxTokens!.isNotEmpty) {
      requestBody['max_tokens'] = int.tryParse(config.maxTokens!);
    }
    if (config.frequencyPenalty != null &&
        config.frequencyPenalty!.isNotEmpty) {
      requestBody['frequency_penalty'] =
          double.tryParse(config.frequencyPenalty!);
    }
    if (config.presencePenalty != null && config.presencePenalty!.isNotEmpty) {
      requestBody['presence_penalty'] =
          double.tryParse(config.presencePenalty!);
    }

    // 发送POST请求
    Response response = await dio.post(
      '${config.baseUrl}/v1/chat/completions',
      data: requestBody,
      options: Options(headers: headers),
    );

    debugPrint("幽灵指令发送成功: ${response.statusCode}");
  } catch (e) {
    debugPrint("幽灵指令发送失败: $e");
  }
}

class LongingAlgorithmService {
  /// 初始化后台服务
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
      ),
    );

    debugPrint("渴望算法服务初始化完成");
  }

  /// 启动后台服务
  static Future<void> start() async {
    await FlutterBackgroundService().startService();
  }

  /// 停止后台服务
  static Future<void> stop() async {
    FlutterBackgroundService().invoke('stop');
  }
}
