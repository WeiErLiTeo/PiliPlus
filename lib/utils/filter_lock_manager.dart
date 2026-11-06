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
  static DateTime? _justAdvancedAt;
  static Timer? _holdTimer;
  static Offset? _downPosition;
  static bool _holdTriggered = false;

  static void _resetSequence() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _stage = 0;
    _tapCounter = 0;
    _lastActionTime = null;
    _justAdvancedAt = null;
    _downPosition = null;
    _holdTriggered = false;
  }

  static bool _isExpired([int maxSeconds = 25]) {
    if (_lastActionTime == null) return false;
    return DateTime.now().difference(_lastActionTime!).inSeconds > maxSeconds;
  }

  static bool _isInGracePeriod() {
    if (_justAdvancedAt == null) return false;
    return DateTime.now().difference(_justAdvancedAt!).inMilliseconds < 2500;
  }

  static void _showStageToast(String msg) {
    HapticFeedback.mediumImpact();
    SmartDialog.showToast(
      msg,
      alignment: Alignment.bottomCenter,
      displayType: SmartToastType.onlyRefresh,
    );
  }

  static bool checkLockedAndToast() {
    if (!isLocked) return false;
    SmartDialog.showToast(
      '当前处于上锁状态，无法关闭或修改过滤规则',
      alignment: Alignment.bottomCenter,
      displayType: SmartToastType.onlyRefresh,
    );
    return true;
  }

  static Future<void> lockWithConfirm(
    BuildContext context,
    VoidCallback onRefresh,
  ) async {
    if (isLocked) {
      if (!onNodeTap(context, 1, onRefresh)) {
        checkLockedAndToast();
      }
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
      SmartDialog.showToast(
        '过滤设置已上锁',
        alignment: Alignment.bottomCenter,
      );
    }
  }

  /// Returns true if this tap was handled by the unlock state machine (so caller shouldn't overwrite toast).
  static bool onNodeTap(
    BuildContext context,
    int nodeId,
    VoidCallback onRefresh,
  ) {
    if (!isLocked) return false;
    if (_holdTriggered) {
      _holdTriggered = false;
      return true;
    }
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
          _justAdvancedAt = DateTime.now();
          _showStageToast('阶段 1/5 已通过');
        }
        return true;
      } else {
        _resetSequence();
        return false;
      }
    } else if (_stage == 1) {
      if (nodeId == 1 && _isInGracePeriod()) {
        _showStageToast('阶段 1/5 已通过');
        return true;
      }
      if (nodeId == 2 && _isInGracePeriod()) {
        return true;
      }
      _resetSequence();
      return false;
    } else if (_stage == 2) {
      if (nodeId == 2 && _isInGracePeriod()) {
        return true;
      }
      if (nodeId == 3) {
        _tapCounter++;
        if (_tapCounter == 5) {
          _stage = 3;
          _tapCounter = 0;
          _justAdvancedAt = DateTime.now();
          _showStageToast('阶段 3/5 已通过');
        }
        return true;
      } else {
        _resetSequence();
        return false;
      }
    } else if (_stage == 3) {
      if (nodeId == 3 && _isInGracePeriod()) {
        _showStageToast('阶段 3/5 已通过');
        return true;
      }
      if (nodeId == 4 && _isInGracePeriod()) {
        return true;
      }
      _resetSequence();
      return false;
    } else if (_stage == 4) {
      if (nodeId == 4 && _isInGracePeriod()) {
        return true;
      }
      if (nodeId == 1) {
        _tapCounter++;
        if (_tapCounter == 3) {
          _resetSequence();
          _showStageToast('阶段 5/5 已通过');
          _showTediousChallengeDialog(context, onRefresh);
        }
        return true;
      } else {
        _resetSequence();
        return false;
      }
    }
    return false;
  }

  static void onNodeHoldStart(int nodeId, Offset position) {
    if (!isLocked) return;
    if (_isExpired()) {
      _resetSequence();
      return;
    }
    _holdTimer?.cancel();
    _downPosition = position;
    _holdTriggered = false;

    if (_stage == 1 && nodeId == 2) {
      _holdTimer = Timer(const Duration(milliseconds: 3500), () {
        if (_stage == 1) {
          _stage = 2;
          _tapCounter = 0;
          _lastActionTime = DateTime.now();
          _justAdvancedAt = DateTime.now();
          _holdTriggered = true;
          _showStageToast('阶段 2/5 已通过，请松手');
        }
      });
    } else if (_stage == 3 && nodeId == 4) {
      _holdTimer = Timer(const Duration(milliseconds: 4500), () {
        if (_stage == 3) {
          _stage = 4;
          _tapCounter = 0;
          _lastActionTime = DateTime.now();
          _justAdvancedAt = DateTime.now();
          _holdTriggered = true;
          _showStageToast('阶段 4/5 已通过，请松手');
        }
      });
    }
  }

  static void onNodeHoldMove(int nodeId, Offset position) {
    if (_downPosition != null &&
        (position - _downPosition!).distance > 24.0) {
      _holdTimer?.cancel();
      _holdTimer = null;
    }
  }

  static void onNodeHoldEnd(int nodeId) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _downPosition = null;
  }

  static void onNodeHoldCancel(int nodeId) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _downPosition = null;
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
                            SmartDialog.showToast(
                              '输入内容不匹配，进度已重置',
                              alignment: Alignment.bottomCenter,
                            );
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
                            SmartDialog.showToast(
                              '已解除锁定',
                              alignment: Alignment.bottomCenter,
                            );
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
