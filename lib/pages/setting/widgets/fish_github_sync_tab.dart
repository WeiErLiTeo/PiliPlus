import 'package:PiliPlus/utils/fish_github_sync.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart' hide StatefulBuilder;

class FishGithubSyncTab extends StatefulWidget {
  final VoidCallback onDataChanged;

  const FishGithubSyncTab({super.key, required this.onDataChanged});

  @override
  State<FishGithubSyncTab> createState() => _FishGithubSyncTabState();
}

class _FishGithubSyncTabState extends State<FishGithubSyncTab> {
  late final TextEditingController _repoCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _pathCtrl;
  late final TextEditingController _tokenCtrl;
  late bool _autoUpload;
  bool _obscureToken = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repoCtrl = TextEditingController(text: FishGithubSync.repo);
    _branchCtrl = TextEditingController(text: FishGithubSync.branch);
    _pathCtrl = TextEditingController(text: FishGithubSync.filePath);
    _tokenCtrl = TextEditingController(text: FishGithubSync.token);
    _autoUpload = FishGithubSync.autoUploadOnMark;
  }

  @override
  void dispose() {
    _repoCtrl.dispose();
    _branchCtrl.dispose();
    _pathCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _saveConfig({bool toast = true}) {
    FishGithubSync.saveConfig(
      newRepo: _repoCtrl.text,
      newBranch: _branchCtrl.text,
      newPath: _pathCtrl.text,
      newToken: _tokenCtrl.text,
      newAutoUpload: _autoUpload,
    );
    _repoCtrl.text = FishGithubSync.repo;
    _branchCtrl.text = FishGithubSync.branch;
    _pathCtrl.text = FishGithubSync.filePath;
    if (toast) {
      SmartDialog.showToast('GitHub 同步配置已保存');
    }
    if (mounted) setState(() {});
    widget.onDataChanged();
  }

  Future<void> _runTask(Future<FishGithubSyncResult> Function() task) async {
    if (_busy) return;
    _saveConfig(toast: false);
    setState(() => _busy = true);
    try {
      final res = await task();
      SmartDialog.showToast(res.message);
      widget.onDataChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawUrl = FishGithubSync.rawSubscribeUrl;
    final pendingCount = FishGithubSync.pendingUploadMap.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '把你在评论区标记或待审池转正的鱼号自动追加到自己的 GitHub .txt 仓库，方便换机同步或分享 raw 链接给别人订阅。\n'
            '建议使用细粒度 Token（仅勾选单个仓库的 Contents 读写权限）。Token 仅存本地缓存，不会被「导出全部设置」打包出去。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _repoCtrl,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'GitHub 仓库（格式：用户名/仓库名）',
              hintText: '例如：WeiErLiTeo/bili-fish-list',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _branchCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '分支',
                    hintText: 'main',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _pathCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '目标 .txt 路径',
                    hintText: 'fish.txt',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            obscureText: _obscureToken,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'GitHub Token（PAT）',
              hintText: 'github_pat_... 或 ghp_...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureToken
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureToken = !_obscureToken),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '长按「标记为鱼」/待审池转正时自动上传',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Transform.scale(
                scale: 0.8,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: _autoUpload,
                  onChanged: (v) {
                    setState(() => _autoUpload = v);
                    _saveConfig(toast: false);
                  },
                ),
              ),
            ],
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '当前有 $pendingCount 条待上传记录（断网或失败时自动保留，可点下方补传）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.save_outlined, size: 16),
                label: const Text('保存配置', style: TextStyle(fontSize: 12)),
                onPressed: _busy ? null : _saveConfig,
              ),
              ActionChip(
                avatar: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 16),
                label: const Text('测试连接', style: TextStyle(fontSize: 12)),
                onPressed: _busy
                    ? null
                    : () => _runTask(FishGithubSync.testConnection),
              ),
              ActionChip(
                avatar: const Icon(Icons.cloud_sync_outlined, size: 16),
                label: const Text('双向同步云端', style: TextStyle(fontSize: 12)),
                onPressed: _busy
                    ? null
                    : () => _runTask(FishGithubSync.twoWaySync),
              ),
              if (pendingCount > 0)
                ActionChip(
                  avatar: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text(
                    '补传待传($pendingCount)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _busy
                      ? null
                      : () => _runTask(
                            () => FishGithubSync.flushPendingUploads(
                              showToast: false,
                            ),
                          ),
                ),
              if (rawUrl.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.link, size: 16),
                  label: const Text('复制 raw 订阅链接', style: TextStyle(fontSize: 12)),
                  onPressed: () => Utils.copyText(rawUrl),
                ),
            ],
          ),
          if (rawUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Raw 订阅地址：\n$rawUrl',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
