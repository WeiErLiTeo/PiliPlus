import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/pages/setting/widgets/normal_item.dart';
import 'package:PiliPlus/pages/setting/widgets/popup_item.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/switch_item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, Clipboard, ClipboardData;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide PopupMenuItemSelected;

@immutable
sealed class SettingsModel {
  final String? subtitle;
  final Widget? leading;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? titleStyle;

  String? get title;
  Widget get widget;
  String get effectiveTitle;
  String? get effectiveSubtitle;

  const SettingsModel({
    this.subtitle,
    this.leading,
    this.contentPadding,
    this.titleStyle,
  });
}

class SplitModel extends SettingsModel {
  const SplitModel({
    super.contentPadding,
    super.titleStyle,
    required this.normalModel,
    required this.switchModel,
  });

  @override
  String? get effectiveSubtitle => normalModel.effectiveSubtitle;

  @override
  String get effectiveTitle => normalModel.effectiveTitle;

  @override
  String? get title => normalModel.title;

  final NormalModel normalModel;

  final SwitchModel switchModel;

  @override
  Widget get widget => SetSwitchItem(
    title: effectiveTitle,
    subtitle: effectiveSubtitle,
    setKey: switchModel.setKey,
    defaultVal: switchModel.defaultVal,
    onChanged: switchModel.onChanged,
    needReboot: switchModel.needReboot,
    leading: normalModel.leading,
    onTap: switchModel.onTap,
    contentPadding: contentPadding,
    titleStyle: titleStyle,
    isSplit: true,
  );
}

class PopupModel<T extends EnumWithLabel> extends SettingsModel {
  const PopupModel({
    required this.title,
    super.leading,
    super.contentPadding,
    super.titleStyle,
    required this.value,
    required this.items,
    required this.onSelected,
  });

  @override
  String? get effectiveSubtitle => null;

  @override
  String get effectiveTitle => title;

  @override
  final String title;

  final ValueGetter<T> value;
  final Iterable<T> items;
  final PopupMenuItemSelected<T> onSelected;

  @override
  Widget get widget => PopupListTile<T>(
    safeArea: false,
    leading: leading,
    title: Text(title),
    value: () {
      final v = value();
      return (v, v.label);
    },
    itemBuilder: (_) => enumItemBuilder(items),
    onSelected: onSelected,
  );
}

class NormalModel extends SettingsModel {
  @override
  final String? title;
  final ValueGetter<String>? getTitle;
  final ValueGetter<String>? getSubtitle;
  final Widget Function(ThemeData theme)? getTrailing;
  final void Function(BuildContext context, VoidCallback setState)? onTap;

  const NormalModel({
    super.subtitle,
    super.leading,
    super.contentPadding,
    super.titleStyle,
    this.title,
    this.getTitle,
    this.getSubtitle,
    this.getTrailing,
    this.onTap,
  }) : assert(title != null || getTitle != null);

  const NormalModel.split({
    super.subtitle,
    super.leading,
    super.contentPadding,
    super.titleStyle,
    this.title,
    this.getTitle,
    this.getSubtitle,
    this.getTrailing,
  }) : onTap = null,
       assert(title != null || getTitle != null);

  @override
  String get effectiveTitle => title ?? getTitle!();
  @override
  String? get effectiveSubtitle => subtitle ?? getSubtitle?.call();

  @override
  Widget get widget => NormalItem(
    title: title,
    getTitle: getTitle,
    subtitle: subtitle,
    getSubtitle: getSubtitle,
    leading: leading,
    getTrailing: getTrailing,
    onTap: onTap,
    contentPadding: contentPadding,
    titleStyle: titleStyle,
  );
}

class SwitchModel extends SettingsModel {
  @override
  final String? title;
  final String setKey;
  final bool defaultVal;
  final ValueChanged<bool>? onChanged;
  final bool needReboot;
  final void Function(BuildContext context)? onTap;

  const SwitchModel({
    super.subtitle,
    super.leading,
    super.contentPadding,
    super.titleStyle,
    required String this.title,
    required this.setKey,
    this.defaultVal = false,
    this.onChanged,
    this.needReboot = false,
    this.onTap,
  });

  const SwitchModel.split({
    required this.setKey,
    this.defaultVal = false,
    this.needReboot = false,
    this.onChanged,
    this.onTap,
  }) : title = null;

  @override
  String get effectiveTitle => title!;
  @override
  String? get effectiveSubtitle => subtitle;

  @override
  Widget get widget => SetSwitchItem(
    title: title!,
    subtitle: subtitle,
    setKey: setKey,
    defaultVal: defaultVal,
    onChanged: onChanged,
    needReboot: needReboot,
    leading: leading,
    onTap: onTap,
    contentPadding: contentPadding,
    titleStyle: titleStyle,
  );
}

SettingsModel getBanWordModel({
  required String title,
  required String key,
  required ValueChanged<RegExp> onChanged,
  String? banScope,
}) {
  String banWord = GStorage.setting.get(key, defaultValue: '');
  return NormalModel(
    leading: const Icon(Icons.filter_alt_outlined),
    title: title,
    getSubtitle: () {
      final subtitle = banWord.isEmpty ? "点击添加" : banWord;
      if (banScope != null) {
        return '作用域: $banScope\n$subtitle';
      }
      return subtitle;
    },
    onTap: (context, setState) {
      final textController = TextEditingController(text: banWord);
      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            constraints: Style.dialogFixedConstraints,
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('使用|隔开，如：尝试|测试'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    textInputAction: TextInputAction.newline,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.paste_outlined, size: 16),
                        label: const Text('粘贴/追加剪贴板', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          final clip = data?.text?.trim();
                          if (clip == null || clip.isEmpty) {
                            SmartDialog.showToast('剪贴板为空');
                            return;
                          }
                          String formatted = clip
                              .replaceAll(RegExp(r'[\r\n,，、;；\s]+'), '|')
                              .replaceAll(RegExp(r'\|+'), '|');
                          if (formatted.startsWith('|')) {
                            formatted = formatted.substring(1);
                          }
                          if (formatted.endsWith('|')) {
                            formatted = formatted.substring(0, formatted.length - 1);
                          }
                          if (formatted.isEmpty) return;
                          final cur = textController.text.trim();
                          if (cur.isNotEmpty) {
                            textController.text =
                                cur.endsWith('|') ? '$cur$formatted' : '$cur|$formatted';
                          } else {
                            textController.text = formatted;
                          }
                          textController.selection = TextSelection.collapsed(
                            offset: textController.text.length,
                          );
                          SmartDialog.showToast('已追加剪贴板内容');
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('插入 |', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          final text = textController.text;
                          final selection = textController.selection;
                          if (selection.isValid && selection.start >= 0) {
                            final newText = text.replaceRange(
                              selection.start,
                              selection.end,
                              '|',
                            );
                            textController.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(
                                offset: selection.start + 1,
                              ),
                            );
                          } else {
                            textController.text = '$text|';
                            textController.selection = TextSelection.collapsed(
                              offset: textController.text.length,
                            );
                          }
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('复制', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          if (textController.text.isEmpty) {
                            SmartDialog.showToast('内容为空');
                            return;
                          }
                          Utils.copyText(textController.text);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.clear_all_outlined, size: 16),
                        label: const Text('清空', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          textController.clear();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: Get.back,
                child: Text(
                  '取消',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
              TextButton(
                child: const Text('保存'),
                onPressed: () {
                  String val = textController.text.trim();
                  val = val.replaceAll(RegExp(r'\|+'), '|');
                  if (val.startsWith('|')) val = val.substring(1);
                  if (val.endsWith('|')) val = val.substring(0, val.length - 1);
                  try {
                    final reg = RegExp(val, caseSensitive: false);
                    Get.back();
                    banWord = val;
                    setState();
                    onChanged(reg);
                    SmartDialog.showToast('已保存');
                    GStorage.setting.put(key, banWord);
                  } catch (e) {
                    SmartDialog.showToast('正则表达式格式不合法: $e');
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}

SettingsModel getVideoFilterSelectModel({
  required String title,
  String? subtitle,
  String? suffix,
  required String key,
  required List<int> values,
  int defaultValue = 0,
  bool isFilter = true,
  String? filterScope,
  ValueChanged<int>? onChanged,
}) {
  assert(!isFilter || onChanged != null);
  int value = GStorage.setting.get(key, defaultValue: defaultValue);
  return NormalModel(
    title: '$title${isFilter ? '过滤' : ''}',
    leading: const Icon(Icons.timelapse_outlined),
    subtitle: subtitle,
    getSubtitle: subtitle == null
        ? () {
            if (isFilter) {
              final subtitle = '过滤掉$title小于「$value${suffix ?? ""}」的视频';
              if (filterScope != null) {
                return '作用域: $filterScope\n$subtitle';
              }
              return subtitle;
            }
            return '当前$title:「$value${suffix ?? ""}」';
          }
        : null,
    onTap: (context, setState) async {
      var result = await showDialog<int>(
        context: context,
        builder: (context) => SelectDialog<int>(
          title: '选择$title${isFilter ? '（0即不过滤）' : ''}',
          value: value,
          values:
              (values
                    ..addIf(!values.contains(value), value)
                    ..sort())
                  .map((e) => (e, suffix == null ? e.toString() : '$e $suffix'))
                  .toList()
                ..add((-1, '自定义')),
        ),
      );
      if (result != null) {
        if (result == -1 && context.mounted) {
          String valueStr = '';
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('自定义$title'),
              content: TextField(
                autofocus: true,
                onChanged: (value) => valueStr = value,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(suffixText: suffix),
              ),
              actions: [
                TextButton(
                  onPressed: Get.back,
                  child: Text(
                    '取消',
                    style: TextStyle(color: ColorScheme.of(context).outline),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    try {
                      result = int.parse(valueStr);
                      Get.back();
                    } catch (e) {
                      SmartDialog.showToast(e.toString());
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
        if (result != -1) {
          value = result!;
          setState();
          onChanged?.call(value);
          GStorage.setting.put(key, value);
        }
      }
    },
  );
}
