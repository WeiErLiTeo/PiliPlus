import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/reply/fish_filter_strictness.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/utils/comment_fish_filter.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart'
    show Clipboard, FilteringTextInputFormatter;
import 'package:flutter/widgets.dart' show StatefulBuilder;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide StatefulBuilder;

List<SettingsModel> buildFishFilterSettings() => [
  NormalModel(
    title: 'AI 水军（防鱼灾）自动识别',
    leading: const Icon(Icons.shield_outlined),
    getSubtitle: () =>
        '当前强度：${CommentFishFilter.strictness.label}\n'
        '纯本地多维打分（昵称/话术/RP括号/长文结构/账号权重），不检测头像',
    getTrailing: (theme) => StatefulBuilder(
      builder: (context, setSwitchState) {
        final isEnabled = GStorage.setting.get(
          SettingBoxKey.enableCommentFishFilter,
          defaultValue: true,
        );
        return Transform.scale(
          scale: 0.8,
          alignment: Alignment.centerRight,
          child: Switch(
            value: isEnabled,
            onChanged: (val) {
              GStorage.setting.put(SettingBoxKey.enableCommentFishFilter, val);
              CommentFishFilter.enableFishFilter = val;
              setSwitchState(() {});
            },
          ),
        );
      },
    ),
    onTap: (context, setState) async {
      final res = await showDialog<FishFilterStrictness>(
        context: context,
        builder: (context) => SelectDialog<FishFilterStrictness>(
          title: '选择防鱼灾打分严格度',
          value: CommentFishFilter.strictness,
          values: FishFilterStrictness.values
              .map((e) => (e, e.label))
              .toList(),
        ),
      );
      if (res != null) {
        await GStorage.setting.put(
          SettingBoxKey.commentFishStrictness,
          res.index,
        );
        CommentFishFilter.strictness = res;
        setState();
      }
    },
  ),
  getBanWordModel(
    title: '评论者昵称过滤',
    key: SettingBoxKey.banNameForReply,
    banScope: '评论区昵称',
    onChanged: (value) {
      CommentFishFilter.replyNameRegExp = value;
      CommentFishFilter.enableNameFilter =
          CommentFishFilter.enableBanNameForReply && value.pattern.isNotEmpty;
    },
    enableKey: SettingBoxKey.enableBanNameForReply,
    onEnableChanged: (val) {
      CommentFishFilter.enableBanNameForReply = val;
      CommentFishFilter.enableNameFilter =
          val && CommentFishFilter.replyNameRegExp.pattern.isNotEmpty;
    },
  ),
  NormalModel(
    title: '低等级评论过滤',
    leading: const Icon(Icons.filter_list_outlined),
    getSubtitle: () {
      final minLv = CommentFishFilter.minLevelForReply;
      if (minLv <= 0) {
        return '作用域: 评论区\n当前不过滤（点击设置最低等级门槛）';
      }
      return '作用域: 评论区\n过滤掉低于 Lv$minLv 的评论（即屏蔽 Lv0~Lv${minLv - 1}）';
    },
    getTrailing: (theme) => StatefulBuilder(
      builder: (context, setSwitchState) {
        final isEnabled = GStorage.setting.get(
          SettingBoxKey.enableMinLevelForReply,
          defaultValue: true,
        );
        return Transform.scale(
          scale: 0.8,
          alignment: Alignment.centerRight,
          child: Switch(
            value: isEnabled,
            onChanged: (val) {
              GStorage.setting.put(SettingBoxKey.enableMinLevelForReply, val);
              CommentFishFilter.enableMinLevelForReply = val;
              setSwitchState(() {});
            },
          ),
        );
      },
    ),
    onTap: (context, setState) async {
      final res = await showDialog<int>(
        context: context,
        builder: (context) => SelectDialog<int>(
          title: '选择评论者最低等级门槛',
          value: CommentFishFilter.minLevelForReply,
          values: const [
            (0, '0（不过滤）'),
            (1, 'Lv1 及以上（屏蔽 Lv0）'),
            (2, 'Lv2 及以上（屏蔽 Lv0~1）'),
            (3, 'Lv3 及以上（屏蔽 Lv0~2）'),
            (4, 'Lv4 及以上（屏蔽 Lv0~3）'),
            (5, 'Lv5 及以上（屏蔽 Lv0~4）'),
          ],
        ),
      );
      if (res != null) {
        await GStorage.setting.put(SettingBoxKey.minLevelForReply, res);
        CommentFishFilter.minLevelForReply = res;
        setState();
      }
    },
  ),
  NormalModel(
    title: '本地 UID 黑白名单与 .txt 订阅',
    leading: const Icon(Icons.playlist_remove_outlined),
    getSubtitle: () =>
        '本地黑名单 ${CommentFishFilter.fishBlockMids.length} 人 · '
        '活人白名单 ${CommentFishFilter.humanWhiteMids.length} 人 · '
        '订阅 ${CommentFishFilter.subscribedBlockMids.length} 人\n'
        '评论区与推荐/热门/搜索视频均生效，支持 .txt 在线编辑与导入导出',
    onTap: (context, setState) {
      FishBlocklistDialog.show(context).whenComplete(setState);
    },
  ),
];

class FishBlocklistDialog extends StatefulWidget {
  const FishBlocklistDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const FishBlocklistDialog(),
    );
  }

  @override
  State<FishBlocklistDialog> createState() => _FishBlocklistDialogState();
}

class _FishBlocklistDialogState extends State<FishBlocklistDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _searchKeyword = '';
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportTxtFile({
    required String prefix,
    required String content,
  }) async {
    final name =
        'piliplus_${prefix}_${DateFormatUtils.only0_9.format(DateTime.now())}.txt';
    await StorageUtils.saveBytes2File(
      name: name,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
  }

  Future<String?> _pickTxtOrJsonFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'json'],
      );
      if (result == null) return null;
      return await result.xFile.readAsString();
    } catch (e) {
      SmartDialog.showToast('读取文件失败：$e');
      return null;
    }
  }

  Future<void> _openTxtEditor({
    required String title,
    required String initialText,
    required String exportPrefix,
    required int Function(String text) onSave,
    bool warnIfLarge = false,
  }) async {
    final lineCount = '\n'.allMatches(initialText).length + 1;
    if (warnIfLarge && lineCount > 2500) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('文件行数较多'),
          content: Text(
            '当前订阅 .txt 共约 $lineCount 行，直接在手机输入框打开可能会卡顿。\n'
            '建议先导出为 .txt 用外部文本编辑器修改后再导入，或点击下方强制打开。',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: 'cancel'),
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () => Get.back(result: 'export'),
              child: const Text('导出 .txt'),
            ),
            TextButton(
              onPressed: () => Get.back(result: 'force'),
              child: const Text('仍然编辑'),
            ),
          ],
        ),
      );
      if (action == 'export') {
        await _exportTxtFile(prefix: exportPrefix, content: initialText);
        return;
      }
      if (action != 'force') return;
    }

    if (!mounted) return;
    final controller = TextEditingController(text: initialText);
    await showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          constraints: Style.dialogFixedConstraints,
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每行一个 UID，支持 # 写备注（兼容 bilibili-blocker .txt 与 JSON）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    minLines: 8,
                    maxLines: 14,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                      hintText: '12345678 # 备注\n87654321',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.paste_outlined, size: 16),
                        label: const Text('追加剪贴板', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          final clip = data?.text?.trim();
                          if (clip == null || clip.isEmpty) {
                            SmartDialog.showToast('剪贴板为空');
                            return;
                          }
                          final cur = controller.text.trimRight();
                          controller.text = cur.isEmpty ? '$clip\n' : '$cur\n$clip\n';
                          SmartDialog.showToast('已追加剪贴板内容');
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.file_open_outlined, size: 16),
                        label: const Text('从文件载入', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final raw = await _pickTxtOrJsonFile();
                          if (raw != null) {
                            final cur = controller.text.trimRight();
                            controller.text =
                                cur.isEmpty ? raw : '$cur\n${raw.trim()}\n';
                            SmartDialog.showToast('已载入文件内容（点保存生效）');
                          }
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.save_alt_outlined, size: 16),
                        label: const Text('导出 .txt', style: TextStyle(fontSize: 12)),
                        onPressed: () => _exportTxtFile(
                          prefix: exportPrefix,
                          content: controller.text,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('复制', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          if (controller.text.isEmpty) {
                            SmartDialog.showToast('内容为空');
                            return;
                          }
                          Utils.copyText(controller.text);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.clear_all_outlined, size: 16),
                        label: const Text('清空', style: TextStyle(fontSize: 12)),
                        onPressed: controller.clear,
                      ),
                    ],
                  ),
                ],
              ),
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
              onPressed: () {
                final count = onSave(controller.text);
                Get.back();
                if (mounted) setState(() {});
                SmartDialog.showToast('已保存，共解析 $count 个 UID');
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showAddUidDialog({required bool isWhitelist}) async {
    final uidCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isWhitelist ? '添加活人白名单 UID' : '添加本地黑名单 UID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: uidCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'UID（纯数字）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: '昵称/备注（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              final uid = int.tryParse(uidCtrl.text.trim());
              if (uid == null || uid <= 0) {
                SmartDialog.showToast('请输入有效的数字 UID');
                return;
              }
              if (isWhitelist) {
                CommentFishFilter.addWhiteMid(uid, name: noteCtrl.text);
              } else {
                CommentFishFilter.addFishMid(uid, name: noteCtrl.text);
              }
              Get.back();
              if (mounted) setState(() {});
              SmartDialog.showToast('已添加 UID $uid');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    uidCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _showAddUrlDialog() async {
    final urlCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        constraints: Style.dialogFixedConstraints,
        title: const Text('添加远程 .txt / JSON 订阅链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: urlCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '规则文件 URL（如 GitHub raw 链接）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text(
                    '填入 bilibili-blocker aislop.txt',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () =>
                      urlCtrl.text = CommentFishFilter.presetAiSlopUrl,
                ),
                ActionChip(
                  label: const Text(
                    '填入 bilibili-blocker spam.txt',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () =>
                      urlCtrl.text = CommentFishFilter.presetSpamUrl,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                SmartDialog.showToast('请输入以 http:// 或 https:// 开头的链接');
                return;
              }
              final next = [...CommentFishFilter.subscribeUrls, url];
              CommentFishFilter.saveSubscribeUrls(next);
              Get.back();
              if (mounted) setState(() {});
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    urlCtrl.dispose();
  }

  Future<void> _fetchSubscriptions() async {
    if (_isFetching) return;
    setState(() => _isFetching = true);
    try {
      final res = await CommentFishFilter.fetchSubscriptions();
      if (!mounted) return;
      if (res.successUrls > 0) {
        SmartDialog.showToast(
          '拉取完成：成功 ${res.successUrls} 个，失败 ${res.failedUrls} 个，共 ${res.totalUids} 个 UID',
        );
      } else {
        SmartDialog.showToast(
          res.errors.isNotEmpty ? res.errors.first : '拉取失败',
        );
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Widget _buildUidListTab({required bool isWhitelist}) {
    final map = isWhitelist
        ? CommentFishFilter.humanWhiteMap
        : CommentFishFilter.fishBlockMap;
    final entries = map.entries.where((e) {
      if (_searchKeyword.isEmpty) return true;
      final kw = _searchKeyword.toLowerCase();
      return e.key.toString().contains(kw) ||
          e.value.toLowerCase().contains(kw);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('添加 UID', style: TextStyle(fontSize: 12)),
                onPressed: () => _showAddUidDialog(isWhitelist: isWhitelist),
              ),
              ActionChip(
                avatar: const Icon(Icons.edit_note_outlined, size: 16),
                label: const Text('编辑 .txt', style: TextStyle(fontSize: 12)),
                onPressed: () => _openTxtEditor(
                  title: isWhitelist ? '编辑活人白名单 (.txt)' : '编辑本地黑名单 (.txt)',
                  initialText: CommentFishFilter.exportMapToTxt(
                    map,
                    header: isWhitelist
                        ? 'PiliPlus 活人白名单（不会被本地黑名单、订阅名单和打分误伤）'
                        : 'PiliPlus 本地屏蔽 UID 名单（评论区与视频流均生效）',
                  ),
                  exportPrefix: isWhitelist ? 'human_whitelist' : 'fish_blacklist',
                  onSave: isWhitelist
                      ? CommentFishFilter.replaceHumanWhiteFromText
                      : CommentFishFilter.replaceFishBlockFromText,
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('导入 .txt', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  final raw = await _pickTxtOrJsonFile();
                  if (raw == null) return;
                  final added = isWhitelist
                      ? CommentFishFilter.mergeHumanWhiteFromText(raw)
                      : CommentFishFilter.mergeFishBlockFromText(raw);
                  if (mounted) setState(() {});
                  SmartDialog.showToast('已合并导入 $added 个 UID');
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('导出 .txt', style: TextStyle(fontSize: 12)),
                onPressed: () => _exportTxtFile(
                  prefix: isWhitelist ? 'human_whitelist' : 'fish_blacklist',
                  content: CommentFishFilter.exportMapToTxt(
                    map,
                    header: isWhitelist
                        ? 'PiliPlus 活人白名单'
                        : 'PiliPlus 本地屏蔽 UID 名单',
                  ),
                ),
              ),
            ],
          ),
        ),
        TextField(
          onChanged: (v) => setState(() => _searchKeyword = v.trim()),
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: '搜索 UID 或备注...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    isWhitelist
                        ? '暂无白名单记录\n点上方「编辑 .txt」或「添加 UID」维护'
                        : '暂无本地黑名单记录\n可长按评论「标记为鱼」，或点「编辑 .txt」批量维护',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final item = entries[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      title: Text(
                        item.value.isNotEmpty
                            ? '${item.value} (${item.key})'
                            : 'UID: ${item.key}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: '移除',
                        onPressed: () {
                          if (isWhitelist) {
                            CommentFishFilter.removeWhiteMid(item.key);
                          } else {
                            CommentFishFilter.removeFishMid(item.key);
                          }
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubscribeTab() {
    final urls = CommentFishFilter.subscribeUrls;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Text(
            '当前已生效订阅 UID：${CommentFishFilter.subscribedBlockMids.length} 人（评论区与推荐/热门/搜索视频均屏蔽；活人白名单自动豁免）',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              avatar: const Icon(Icons.add_link, size: 16),
              label: const Text('添加链接', style: TextStyle(fontSize: 12)),
              onPressed: _showAddUrlDialog,
            ),
            ActionChip(
              avatar: _isFetching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: Text(
                _isFetching ? '拉取中...' : '拉取更新',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: _isFetching ? null : _fetchSubscriptions,
            ),
            ActionChip(
              avatar: const Icon(Icons.edit_note_outlined, size: 16),
              label: const Text('编辑订阅 .txt', style: TextStyle(fontSize: 12)),
              onPressed: () => _openTxtEditor(
                title: '编辑订阅规则 (.txt)',
                initialText: CommentFishFilter.getSubscribedTxt(),
                exportPrefix: 'subscribed_uids',
                warnIfLarge: true,
                onSave: CommentFishFilter.replaceSubscribedFromText,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text('导入 .txt', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final raw = await _pickTxtOrJsonFile();
                if (raw == null) return;
                final added = CommentFishFilter.mergeSubscribedFromText(raw);
                if (mounted) setState(() {});
                SmartDialog.showToast(
                  '已合并导入 $added 个 UID，当前共 ${CommentFishFilter.subscribedBlockMids.length} 个',
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('导出 .txt', style: TextStyle(fontSize: 12)),
              onPressed: () => _exportTxtFile(
                prefix: 'subscribed_uids',
                content: CommentFishFilter.getSubscribedTxt(),
              ),
            ),
            if (CommentFishFilter.subscribedBlockMids.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空缓存', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  CommentFishFilter.clearSubscribed();
                  setState(() {});
                  SmartDialog.showToast('已清空订阅缓存');
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: urls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '尚未添加远程订阅链接\n可一键添加社区众包规则（bilibili-blocker）：',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              CommentFishFilter.saveSubscribeUrls([
                                ...CommentFishFilter.subscribeUrls,
                                CommentFishFilter.presetAiSlopUrl,
                              ]);
                              setState(() {});
                            },
                            child: const Text('+ aislop.txt (AI内容号)'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              CommentFishFilter.saveSubscribeUrls([
                                ...CommentFishFilter.subscribeUrls,
                                CommentFishFilter.presetSpamUrl,
                              ]);
                              setState(() {});
                            },
                            child: const Text('+ spam.txt (刷屏号)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: urls.length,
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      title: Text(
                        url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: '删除链接',
                        onPressed: () {
                          final next = [...urls]..removeAt(index);
                          CommentFishFilter.saveSubscribeUrls(next);
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return AlertDialog(
      constraints: Style.dialogFixedConstraints,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      title: const Text('本地 UID 黑白名单与 .txt 订阅'),
      content: SizedBox(
        width: double.maxFinite,
        height: (screenHeight * 0.62).clamp(320.0, 540.0),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: [
                Tab(text: '黑名单(${CommentFishFilter.fishBlockMids.length})'),
                Tab(text: '白名单(${CommentFishFilter.humanWhiteMids.length})'),
                Tab(text: '订阅(${CommentFishFilter.subscribedBlockMids.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUidListTab(isWhitelist: false),
                  _buildUidListTab(isWhitelist: true),
                  _buildSubscribeTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
