import 'dart:async';

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StatefulBuilder;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide StatefulBuilder;

abstract final class FilterLockManager {
  static bool isLocked = Pref.filterLockEnabled;

  static int _stage = 0;
  static int _tapCounter = 0;
  static DateTime? _lastActionTime;
  static DateTime? _longPressStart;

  static void _resetSequence() {
    _stage = 0;
    _tapCounter = 0;
    _lastActionTime = null;
    _longPressStart = null;
  }

  static bool _isExpired([int maxSeconds = 8]) {
    if (_lastActionTime == null) return false;
    return DateTime.now().difference(_lastActionTime!).inSeconds > maxSeconds;
  }

  static bool checkLockedAndToast() {
    if (!isLocked) return false;
    SmartDialog.showToast('当前处于上锁状态，无法关闭或修改过滤规则');
    return true;
  }

  static Future<void> lockWithConfirm(
    BuildContext context,
    VoidCallback onRefresh,
  ) async {
    if (isLocked) {
      onNodeTap(context, 1, onRefresh);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开启过滤上锁模式'),
        content: const Text(
          '上锁后，所有过滤开关、关键词、黑白名单模式及生效博主都将被锁定，无法直接关闭或修改。\n\n确定要立即上锁吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认上锁'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      isLocked = true;
      await GStorage.setting.put(SettingBoxKey.filterLockEnabled, true);
      _resetSequence();
      onRefresh();
      SmartDialog.showToast('过滤设置已上锁');
    }
  }

  static void onNodeTap(
    BuildContext context,
    int nodeId,
    VoidCallback onRefresh,
  ) {
    if (!isLocked) return;
    if (_isExpired()) {
      _resetSequence();
    }
    _lastActionTime = DateTime.now();

    if (_stage == 0) {
      if (nodeId == 1) {
        _tapCounter++;
        if (_tapCounter == 7) {
          _stage = 1;
          _tapCounter = 0;
          HapticFeedback.lightImpact();
        } else if (_tapCounter > 7) {
          _resetSequence();
        }
      } else {
        _resetSequence();
      }
    } else if (_stage == 2) {
      if (nodeId == 3) {
        _tapCounter++;
        if (_tapCounter == 5) {
          _stage = 3;
          _tapCounter = 0;
          HapticFeedback.mediumImpact();
        } else if (_tapCounter > 5) {
          _resetSequence();
        }
      } else {
        _resetSequence();
      }
    } else if (_stage == 4) {
      if (nodeId == 1) {
        _tapCounter++;
        if (_tapCounter == 3) {
          _resetSequence();
          _showTediousChallengeDialog(context, onRefresh);
        }
      } else {
        _resetSequence();
      }
    } else {
      _resetSequence();
    }
  }

  static void onNodeLongPressStart(int nodeId) {
    if (!isLocked) return;
    if (_isExpired()) {
      _resetSequence();
      return;
    }
    _longPressStart = DateTime.now();
  }

  static void onNodeLongPressEnd(int nodeId) {
    if (!isLocked || _longPressStart == null) return;
    final elapsedMs = DateTime.now().difference(_longPressStart!).inMilliseconds;
    _longPressStart = null;
    _lastActionTime = DateTime.now();

    if (_stage == 1 && nodeId == 2) {
      if (elapsedMs >= 3500 && elapsedMs <= 6500) {
        _stage = 2;
        _tapCounter = 0;
        HapticFeedback.heavyImpact();
      } else {
        _resetSequence();
      }
    } else if (_stage == 3 && nodeId == 4) {
      if (elapsedMs >= 4500 && elapsedMs <= 8000) {
        _stage = 4;
        _tapCounter = 0;
        HapticFeedback.heavyImpact();
      } else {
        _resetSequence();
      }
    } else {
      _resetSequence();
    }
  }

  static Future<void> _showTediousChallengeDialog(
    BuildContext context,
    VoidCallback onRefresh,
  ) async {
    const phrases = [
      '我确认现在头脑清醒并非一时冲动关闭过滤规则',
      '解除锁定后依然保持自律绝不无意义刷屏消耗时间',
      '我已经仔细考虑清楚本次修改过滤配置的必要性',
    ];
    int step = 0;
    int countdown = 45;
    Timer? timer;
    final textController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (!ctx.mounted) {
                t.cancel();
                return;
              }
              if (countdown > 0) {
                setDialogState(() {
                  countdown--;
                });
              }
            });

            final targetPhrase = phrases[step];
            return AlertDialog(
              title: Text('解锁验证 (${step + 1}/${phrases.length})'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    countdown > 0
                        ? '冷静等待倒计时：${countdown}s'
                        : '倒计时已完成，请完整手打输入下方文字（禁止粘贴）：',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    targetPhrase,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textController,
                    enabled: countdown == 0,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: '请逐字输入上方文字',
                    ),
                    onChanged: (val) {
                      if ((val.length - targetPhrase.length).abs() == 0 &&
                          val != targetPhrase) {
                        // keep typing
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Get.back();
                  },
                  child: const Text('放弃解锁'),
                ),
                FilledButton(
                  onPressed: countdown > 0
                      ? null
                      : () async {
                          if (textController.text.trim() != targetPhrase) {
                            SmartDialog.showToast('输入内容不匹配，进度已重置');
                            timer?.cancel();
                            Get.back();
                            return;
                          }
                          if (step < phrases.length - 1) {
                            textController.clear();
                            setDialogState(() {
                              step++;
                              countdown = 45;
                            });
                          } else {
                            timer?.cancel();
                            isLocked = false;
                            await GStorage.setting.put(
                              SettingBoxKey.filterLockEnabled,
                              false,
                            );
                            Get.back();
                            onRefresh();
                            SmartDialog.showToast('已解除锁定');
                          }
                        },
                  child: Text(step < phrases.length - 1 ? '下一步' : '完成解锁'),
                ),
              ],
            );
          },
        );
      },
    );
    timer?.cancel();
  }
}
