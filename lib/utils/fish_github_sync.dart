import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/utils/comment_fish_filter.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class FishGithubSyncResult {
  final bool success;
  final int pulledCount;
  final int pushedCount;
  final String message;

  const FishGithubSyncResult({
    required this.success,
    this.pulledCount = 0,
    this.pushedCount = 0,
    required this.message,
  });
}

abstract final class FishGithubSync {
  static String repo = Pref.fishGithubRepo;
  static String branch = Pref.fishGithubBranch;
  static String filePath = Pref.fishGithubPath;
  static String token = Pref.fishGithubToken;
  static bool autoUploadOnMark = Pref.fishGithubAutoUpload;

  static Map<int, String> pendingUploadMap = Pref.fishPendingUploadMap;

  static Timer? _debounceTimer;
  static bool _isFlushing = false;
  static bool _needsReflush = false;

  static bool get isConfigured {
    final r = repo.trim();
    final parts = r.split('/');
    return parts.length == 2 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty &&
        filePath.trim().isNotEmpty &&
        token.trim().isNotEmpty;
  }

  static bool get shouldAutoUpload => isConfigured && autoUploadOnMark;

  static String get normalizedPath =>
      filePath.trim().replaceFirst(RegExp(r'^/+'), '');

  static String get normalizedBranch =>
      branch.trim().isEmpty ? 'main' : branch.trim();

  static String get rawSubscribeUrl {
    final r = repo.trim();
    if (!r.contains('/') || normalizedPath.isEmpty) return '';
    return 'https://raw.githubusercontent.com/$r/$normalizedBranch/$normalizedPath';
  }

  static void saveConfig({
    required String newRepo,
    required String newBranch,
    required String newPath,
    required String newToken,
    required bool newAutoUpload,
  }) {
    repo = newRepo.trim().replaceFirst(
      RegExp(r'^https?://github\.com/'),
      '',
    ).replaceAll(RegExp(r'\.git$'), '').replaceAll(RegExp(r'^/+|/+$'), '');
    branch = newBranch.trim().isEmpty ? 'main' : newBranch.trim();
    filePath = newPath.trim().isEmpty ? 'fish.txt' : newPath.trim();
    token = newToken.trim();
    autoUploadOnMark = newAutoUpload;

    Pref.fishGithubRepo = repo;
    Pref.fishGithubBranch = branch;
    Pref.fishGithubPath = filePath;
    Pref.fishGithubToken = token;
    Pref.fishGithubAutoUpload = autoUploadOnMark;
  }

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Authorization': 'Bearer ${token.trim()}',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'PiliPlus/FishGithubSync',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  static String _apiUrl() {
    final encodedPath = normalizedPath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    return 'https://api.github.com/repos/${repo.trim()}/contents/$encodedPath';
  }

  static String _todayStr() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _formatLine(int uid, String note) {
    final clean = note.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final date = _todayStr();
    if (clean.isEmpty) {
      return '$uid # $date';
    }
    return '$uid # $clean ($date)';
  }

  /// 将单条 UID 加入防抖上传队列（1.5s 内多次标记合并为一次提交，防 409 冲突）
  static void enqueueUpload(int mid, {String note = ''}) {
    if (mid <= 0 || !isConfigured) return;
    pendingUploadMap[mid] = note.trim();
    Pref.fishPendingUploadMap = pendingUploadMap;
    _scheduleFlush();
  }

  static void enqueueBatchUpload(Map<int, String> items) {
    if (items.isEmpty || !isConfigured) return;
    items.forEach((uid, note) {
      if (uid > 0) pendingUploadMap[uid] = note.trim();
    });
    Pref.fishPendingUploadMap = pendingUploadMap;
    _scheduleFlush();
  }

  static void _scheduleFlush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      flushPendingUploads(showToast: true);
    });
  }

  static Future<FishGithubSyncResult> flushPendingUploads({
    bool showToast = false,
  }) async {
    if (!isConfigured) {
      return const FishGithubSyncResult(
        success: false,
        message: '请先填写 GitHub 仓库、路径和 Token',
      );
    }
    if (pendingUploadMap.isEmpty) {
      return const FishGithubSyncResult(
        success: true,
        message: '没有待上传的记录',
      );
    }
    if (_isFlushing) {
      _needsReflush = true;
      return const FishGithubSyncResult(
        success: true,
        message: '正在上传队列中...',
      );
    }

    _isFlushing = true;
    try {
      final batch = Map<int, String>.from(pendingUploadMap);
      final res = await _pushEntriesWithRetry(
        batch,
        commitPrefix: 'add fish',
      );
      if (res.success) {
        for (final uid in batch.keys) {
          pendingUploadMap.remove(uid);
        }
        Pref.fishPendingUploadMap = pendingUploadMap;
        if (showToast) {
          SmartDialog.showToast(res.message);
        }
      } else if (showToast) {
        SmartDialog.showToast('GitHub 上传失败（已留待重试）：${res.message}');
      }
      return res;
    } finally {
      _isFlushing = false;
      if (_needsReflush && pendingUploadMap.isNotEmpty) {
        _needsReflush = false;
        _scheduleFlush();
      }
    }
  }

  /// 双向同步：拉取云端 .txt 合并到本地黑名单，同时把本地多出的黑名单与待传队列推送上去
  static Future<FishGithubSyncResult> twoWaySync() async {
    if (!isConfigured) {
      return const FishGithubSyncResult(
        success: false,
        message: '请先填写 GitHub 仓库、路径和 Token',
      );
    }

    final dio = _createDio();
    try {
      final remote = await _fetchRemoteFile(dio);
      if (remote.error != null) {
        return FishGithubSyncResult(success: false, message: remote.error!);
      }

      int pulled = 0;
      final remoteMap = CommentFishFilter.parseUidText(remote.content);
      for (final e in remoteMap.entries) {
        if (!CommentFishFilter.humanWhiteMids.contains(e.key) &&
            !CommentFishFilter.fishBlockMids.contains(e.key)) {
          CommentFishFilter.fishBlockMap[e.key] = e.value;
          CommentFishFilter.fishBlockMids.add(e.key);
          pulled++;
        }
      }
      if (pulled > 0) {
        Pref.fishBlockMidsMap = CommentFishFilter.fishBlockMap;
      }

      // 合并所有本地黑名单 + 待传队列中尚未在云端的 UID
      final toPush = <int, String>{};
      CommentFishFilter.fishBlockMap.forEach((uid, note) {
        if (!remoteMap.containsKey(uid)) {
          toPush[uid] = note;
        }
      });
      pendingUploadMap.forEach((uid, note) {
        if (!remoteMap.containsKey(uid)) {
          toPush[uid] = note;
        }
      });

      if (toPush.isEmpty && remote.exists) {
        pendingUploadMap.clear();
        Pref.fishPendingUploadMap = pendingUploadMap;
        return FishGithubSyncResult(
          success: true,
          pulledCount: pulled,
          pushedCount: 0,
          message: pulled > 0
              ? '双向同步完成：拉取 $pulled 条，云端已是最新'
              : '云端与本地已一致（共 ${remoteMap.length} 条）',
        );
      }

      final pushRes = await _pushEntriesWithRetry(
        toPush,
        commitPrefix: 'sync fish list',
      );
      if (pushRes.success) {
        pendingUploadMap.clear();
        Pref.fishPendingUploadMap = pendingUploadMap;
        return FishGithubSyncResult(
          success: true,
          pulledCount: pulled,
          pushedCount: pushRes.pushedCount,
          message:
              '双向同步完成：拉取 $pulled 条，上传 ${pushRes.pushedCount} 条',
        );
      }
      return FishGithubSyncResult(
        success: false,
        pulledCount: pulled,
        message: '已拉取 $pulled 条，但上传失败：${pushRes.message}',
      );
    } catch (e) {
      return FishGithubSyncResult(success: false, message: '网络错误：$e');
    } finally {
      dio.close();
    }
  }

  static Future<FishGithubSyncResult> testConnection() async {
    if (!isConfigured) {
      return const FishGithubSyncResult(
        success: false,
        message: '请先填写仓库（owner/repo）、路径和 Token',
      );
    }
    final dio = _createDio();
    try {
      final repoResp = await dio.get(
        'https://api.github.com/repos/${repo.trim()}',
      );
      if (repoResp.statusCode != 200) {
        final msg = _extractApiMsg(repoResp.data, repoResp.statusCode);
        return FishGithubSyncResult(
          success: false,
          message: '仓库访问失败：$msg',
        );
      }

      final remote = await _fetchRemoteFile(dio);
      if (remote.error != null) {
        return FishGithubSyncResult(success: false, message: remote.error!);
      }
      if (!remote.exists) {
        return const FishGithubSyncResult(
          success: true,
          message: '连接成功！目标 .txt 尚未创建，首次上传时会自动创建',
        );
      }
      final count = CommentFishFilter.parseUidText(remote.content).length;
      return FishGithubSyncResult(
        success: true,
        message: '连接成功！云端文件已有 $count 条 UID',
      );
    } catch (e) {
      return FishGithubSyncResult(success: false, message: '连接失败：$e');
    } finally {
      dio.close();
    }
  }

  static Future<FishGithubSyncResult> _pushEntriesWithRetry(
    Map<int, String> entries, {
    required String commitPrefix,
  }) async {
    final dio = _createDio();
    try {
      for (int attempt = 0; attempt < 3; attempt++) {
        final remote = await _fetchRemoteFile(dio);
        if (remote.error != null) {
          return FishGithubSyncResult(success: false, message: remote.error!);
        }

        final existingMap = CommentFishFilter.parseUidText(remote.content);
        final newLines = <String>[];
        final sortedUids = entries.keys.toList()..sort();
        for (final uid in sortedUids) {
          if (!existingMap.containsKey(uid)) {
            newLines.add(_formatLine(uid, entries[uid] ?? ''));
          }
        }

        if (newLines.isEmpty && remote.exists) {
          return const FishGithubSyncResult(
            success: true,
            pushedCount: 0,
            message: '云端已包含这些 UID，无需重复上传',
          );
        }

        final buf = StringBuffer();
        if (remote.content.trim().isNotEmpty) {
          buf.write(remote.content.trimRight());
          buf.writeln();
        } else {
          buf.writeln('# PiliPlus 评论区 AI 鱼号黑名单（每行一个 UID，# 后为备注）');
        }
        for (final line in newLines) {
          buf.writeln(line);
        }

        final encoded = base64Encode(utf8.encode(buf.toString()));
        final commitMsg = newLines.length == 1
            ? '$commitPrefix ${sortedUids.first}'
            : '$commitPrefix (+${newLines.length} UIDs)';

        final payload = <String, dynamic>{
          'message': commitMsg,
          'content': encoded,
          'branch': normalizedBranch,
        };
        if (remote.sha != null && remote.sha!.isNotEmpty) {
          payload['sha'] = remote.sha;
        }

        final putResp = await dio.put(_apiUrl(), data: payload);
        if (putResp.statusCode == 200 || putResp.statusCode == 201) {
          return FishGithubSyncResult(
            success: true,
            pushedCount: newLines.length,
            message: '已上传 ${newLines.length} 条到 GitHub',
          );
        }

        // 409/422 通常是并发 sha 过期，重新拉取最新 sha 重试
        if ((putResp.statusCode == 409 || putResp.statusCode == 422) &&
            attempt < 2) {
          continue;
        }

        final msg = _extractApiMsg(putResp.data, putResp.statusCode);
        return FishGithubSyncResult(success: false, message: msg);
      }

      return const FishGithubSyncResult(
        success: false,
        message: '多次遇到文件冲突，请稍后重试',
      );
    } catch (e) {
      return FishGithubSyncResult(success: false, message: '$e');
    } finally {
      dio.close();
    }
  }

  static Future<({bool exists, String content, String? sha, String? error})>
      _fetchRemoteFile(Dio dio) async {
    final resp = await dio.get(
      _apiUrl(),
      queryParameters: {'ref': normalizedBranch},
    );
    if (resp.statusCode == 404) {
      return (exists: false, content: '', sha: null, error: null);
    }
    if (resp.statusCode != 200) {
      return (
        exists: false,
        content: '',
        sha: null,
        error: _extractApiMsg(resp.data, resp.statusCode),
      );
    }
    final data = resp.data;
    if (data is Map) {
      final sha = data['sha']?.toString();
      final rawBase64 = (data['content'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), '');
      String content = '';
      if (rawBase64.isNotEmpty) {
        content = utf8.decode(base64Decode(rawBase64), allowMalformed: true);
      } else if (data['download_url'] is String) {
        final dlResp = await dio.get<String>(
          data['download_url'] as String,
          options: Options(responseType: ResponseType.plain),
        );
        content = dlResp.data ?? '';
      }
      return (exists: true, content: content, sha: sha, error: null);
    }
    return (
      exists: false,
      content: '',
      sha: null,
      error: 'GitHub 返回数据格式异常',
    );
  }

  static String _extractApiMsg(dynamic data, int? statusCode) {
    if (data is Map && data['message'] != null) {
      return 'HTTP $statusCode: ${data['message']}';
    }
    return 'HTTP ${statusCode ?? "未知错误"}';
  }
}
