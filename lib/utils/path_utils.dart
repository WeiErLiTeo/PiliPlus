import 'dart:io' show Platform, Process;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

late final String tmpDirPath;

late final String appSupportDirPath;

late String downloadPath;

String get defDownloadPath =>
    path.join(appSupportDirPath, PathUtils.downloadDir);

abstract final class PathUtils {
  static const videoNameType1 = '0.mp4';
  static const _fileExt = '.m4s';
  static const audioNameType2 = 'audio$_fileExt';
  static const videoNameType2 = 'video$_fileExt';
  static const coverName = 'cover.jpg';
  static const danmakuName = 'danmaku.pb';
  static const downloadDir = 'download';

  static String buildShadersAbsolutePath(
    String baseDirectory,
    List<String> shaders,
  ) {
    return shaders
        .map((shader) => path.join(baseDirectory, shader))
        .join(Platform.isWindows ? ';' : ':');
  }

  static const _channel = MethodChannel('com.example.piliplus/native');

  static Future<void> openInMt(String dirPath) async {
    if (Platform.isAndroid) {
      try {
        final success = await _channel.invokeMethod<bool>(
          'openInMt',
          {'path': dirPath},
        );
        if (success == false) {
          SmartDialog.showToast('未能打开MT管理器，请检查是否已安装');
        }
      } catch (e) {
        SmartDialog.showToast('打开失败: $e');
      }
    } else {
      openDir(dirPath);
    }
  }

  static Future<void> mergeToMp4({
    required String entryDirPath,
    required String title,
  }) async {
    if (!Platform.isAndroid) {
      SmartDialog.showToast('当前平台暂不支持一键合并');
      return;
    }
    SmartDialog.showLoading(msg: '正在合并为 MP4，请稍候...');
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'mergeToMp4',
        {
          'entryDirPath': entryDirPath,
          'title': title,
        },
      );
      SmartDialog.dismiss(status: SmartStatus.loading);
      if (res?['success'] == true) {
        final outputPath = res?['outputPath'] as String? ?? '';
        SmartDialog.show(
          builder: (context) => AlertDialog(
            title: const Text('合并成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已成功生成完整 MP4 视频，保存路径：'),
                const SizedBox(height: 8),
                SelectableText(
                  outputPath,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '已保存至系统 Download/PiliPlus 目录，可在相册或 MT 管理器中直接查看。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SmartDialog.dismiss();
                  if (outputPath.isNotEmpty) {
                    openInMt(outputPath);
                  }
                },
                child: const Text('在 MT 管理器中查看'),
              ),
              FilledButton(
                onPressed: SmartDialog.dismiss,
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        SmartDialog.showToast('合并失败: ${res?['error'] ?? '未知错误'}');
      }
    } catch (e) {
      SmartDialog.dismiss(status: SmartStatus.loading);
      SmartDialog.showToast('合并出错: $e');
    }
  }

  static Future<void> openDir(String dirPath) async {
    try {
      final String executable;
      if (Platform.isWindows) {
        executable = 'explorer';
      } else if (Platform.isMacOS) {
        executable = 'open';
      } else if (Platform.isLinux) {
        executable = 'xdg-open';
      } else {
        throw UnimplementedError();
      }
      await Process.run(executable, [dirPath]);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }
}
