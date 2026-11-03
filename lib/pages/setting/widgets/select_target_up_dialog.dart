import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/follow.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/follow/list.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SelectTargetUpDialog extends StatefulWidget {
  const SelectTargetUpDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录B站账号再选择关注博主');
      return Future.value();
    }
    return showDialog(
      context: context,
      builder: (context) => const SelectTargetUpDialog(),
    );
  }

  @override
  State<SelectTargetUpDialog> createState() => _SelectTargetUpDialogState();
}

class _SelectTargetUpDialogState extends State<SelectTargetUpDialog> {
  final _selectedMids = <int>{};
  final _allList = <FollowItemModel>[];
  String _keyword = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedMids.addAll(Pref.targetUpMidsForIpFilter);
    _loadFollowings();
  }

  Future<void> _loadFollowings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final myMid = Accounts.main.mid;
      // 加载前两页关注（最多100人）
      final res1 = await FollowHttp.followings(vmid: myMid, pn: 1, ps: 50);
      if (res1 case Success(:final response)) {
        _allList.addAll(response.list ?? []);
        final total = response.total ?? 0;
        if (total > 50) {
          final res2 = await FollowHttp.followings(vmid: myMid, pn: 2, ps: 50);
          if (res2 case Success(response: final r2)) {
            _allList.addAll(r2.list ?? []);
          }
        }
      } else if (res1 case Error(:final errMsg)) {
        _error = errMsg;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<FollowItemModel> get _filteredList {
    if (_keyword.trim().isEmpty) return _allList;
    final k = _keyword.trim().toLowerCase();
    return _allList.where((item) {
      final name = item.uname?.toLowerCase() ?? '';
      return name.contains(k);
    }).toList();
  }

  void _onSave() {
    Pref.targetUpMidsForIpFilter = _selectedMids;
    ReplyGrpc.targetUpMids = Set<int>.from(_selectedMids);
    Get.back();
    SmartDialog.showToast('已保存 ${_selectedMids.length} 位生效博主');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('选择特定关注博主'),
              Text(
                '已选 ${_selectedMids.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: '搜索博主昵称...',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _keyword = val;
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('加载失败: $_error'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadFollowings,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : _filteredList.isEmpty
                    ? const Center(child: Text('没有找到相关博主'))
                    : ListView.builder(
                        itemCount: _filteredList.length,
                        itemBuilder: (context, index) {
                          final item = _filteredList[index];
                          final isChecked = _selectedMids.contains(item.mid);

                          return CheckboxListTile(
                            value: isChecked,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            secondary: NetworkImgLayer(
                              src: item.face,
                              width: 36,
                              height: 36,
                              type: ImageType.avatar,
                            ),
                            title: Text(
                              item.uname ?? 'UID: ${item.mid}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: item.sign?.isNotEmpty == true
                                ? Text(
                                    item.sign!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.outline,
                                    ),
                                  )
                                : null,
                            onChanged: (bool? val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMids.add(item.mid);
                                } else {
                                  _selectedMids.remove(item.mid);
                                }
                              });
                            },
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              if (_selectedMids.length == _allList.length) {
                _selectedMids.clear();
              } else {
                _selectedMids.addAll(_allList.map((e) => e.mid));
              }
            });
          },
          child: Text(
            _selectedMids.length == _allList.length ? '全不选' : '全选',
            style: TextStyle(color: colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: Get.back,
          child: Text('取消', style: TextStyle(color: colorScheme.outline)),
        ),
        FilledButton(
          onPressed: _onSave,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
