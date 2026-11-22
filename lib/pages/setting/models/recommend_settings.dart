import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/rcmd_source.dart';
import 'package:PiliPlus/models/common/reply/comment_ip_filter_mode.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/fish_blocklist_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/select_target_up_dialog.dart';
import 'package:PiliPlus/utils/member_archive_filter.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/search_filter.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide StatefulBuilder;

List<SettingsModel> get recommendSettings => [
  NormalModel(
    title: '首页推荐来源',
    getSubtitle: () => Pref.rcmdSource.label,
    leading: const Icon(Icons.swap_horiz_outlined),
    onTap: _showRcmdSourceDialog,
  ),
  SwitchModel(
    title: '保留首页推荐刷新',
    subtitle: '下拉刷新时保留上次内容',
    leading: const Icon(Icons.refresh),
    setKey: SettingBoxKey.enableSaveLastData,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..enableSaveLastData = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  SwitchModel(
    title: '显示上次看到位置提示',
    subtitle: '保留上次推荐时，在上次刷新位置显示提示',
    leading: const Icon(Icons.tips_and_updates_outlined),
    setKey: SettingBoxKey.savedRcmdTip,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..savedRcmdTip = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  getVideoFilterSelectModel(
    title: '点赞率',
    suffix: '%',
    key: SettingBoxKey.minLikeRatioForRecommend,
    values: [0, 1, 2, 3, 4],
    onChanged: (value) => RecommendFilter.minLikeRatioForRecommend = value,
    filterScope: 'Web推荐、热门、分区',
    enableKey: SettingBoxKey.enableMinLikeRatioForRecommend,
    onEnableChanged: (val) =>
        RecommendFilter.enableMinLikeRatioForRecommend = val,
  ),
  getBanWordModel(
    title: '标题关键词过滤',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter =
          RecommendFilter.enableBanWordForRecommend && value.pattern.isNotEmpty;
    },
    banScope: '推荐、热门、分区、相关视频',
    enableKey: SettingBoxKey.enableBanWordForRecommend,
    onEnableChanged: (val) {
      RecommendFilter.enableBanWordForRecommend = val;
      RecommendFilter.enableFilter =
          val && RecommendFilter.rcmdRegExp.pattern.isNotEmpty;
    },
  ),
  getBanWordModel(
    title: '搜索结果过滤',
    key: SettingBoxKey.banWordForSearch,
    onChanged: (value) {
      SearchFilter.searchRegExp = value;
      SearchFilter.enableFilter =
          SearchFilter.enableBanWordForSearch && value.pattern.isNotEmpty;
    },
    banScope: '搜索结果列表（标题与标签）',
    enableKey: SettingBoxKey.enableBanWordForSearch,
    onEnableChanged: (val) {
      SearchFilter.enableBanWordForSearch = val;
      SearchFilter.enableFilter =
          val && SearchFilter.searchRegExp.pattern.isNotEmpty;
    },
  ),
  getBanWordModel(
    title: 'UP主主页视频过滤',
    key: SettingBoxKey.banWordForMemberArchive,
    onChanged: (value) {
      MemberArchiveFilter.memberArchiveRegExp = value;
      MemberArchiveFilter.enableFilter =
          MemberArchiveFilter.enableBanWordForMemberArchive &&
          value.pattern.isNotEmpty;
    },
    banScope: 'UP主个人主页视频投稿',
    enableKey: SettingBoxKey.enableBanWordForMemberArchive,
    onEnableChanged: (val) {
      MemberArchiveFilter.enableBanWordForMemberArchive = val;
      MemberArchiveFilter.enableFilter =
          val && MemberArchiveFilter.memberArchiveRegExp.pattern.isNotEmpty;
    },
  ),
  PopupModel<CommentIpFilterMode>(
    title: 'UP主主页过滤-博主特定模式',
    leading: const Icon(Icons.tune_outlined),
    value: () => Pref.memberArchiveFilterMode,
    items: CommentIpFilterMode.values,
    onSelected: (value, setState) {
      GStorage.setting.put(SettingBoxKey.memberArchiveFilterMode, value.index);
      MemberArchiveFilter.memberArchiveFilterMode = value;
      setState();
    },
  ),
  NormalModel(
    title: 'UP主主页过滤-选择生效博主',
    leading: const Icon(Icons.people_outline),
    getSubtitle: () =>
        '从关注列表中勾选，当前已选 ${Pref.targetUpMidsForMemberArchiveFilter.length} 位博主',
    onTap: (context, setState) {
      SelectTargetUpDialog.show(
        context,
        title: 'UP主主页过滤-选择生效博主',
        initialMids: Pref.targetUpMidsForMemberArchiveFilter,
        onSaveMids: (mids) {
          Pref.targetUpMidsForMemberArchiveFilter = mids;
          MemberArchiveFilter.targetUpMids = mids;
        },
      ).whenComplete(setState);
    },
  ),
  getBanWordModel(
    title: '分区关键词过滤',
    key: SettingBoxKey.banWordForZone,
    onChanged: (value) {
      VideoHttp.zoneRegExp = value;
      VideoHttp.enableFilter =
          VideoHttp.enableBanWordForZone && value.pattern.isNotEmpty;
    },
    banScope: 'App推荐、热门、分区',
    enableKey: SettingBoxKey.enableBanWordForZone,
    onEnableChanged: (val) {
      VideoHttp.enableBanWordForZone = val;
      VideoHttp.enableFilter = val && VideoHttp.zoneRegExp.pattern.isNotEmpty;
    },
  ),
  getVideoFilterSelectModel(
    title: '视频时长',
    suffix: 's',
    key: SettingBoxKey.minDurationForRcmd,
    values: [0, 30, 60, 90, 120],
    onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
    filterScope: '推荐、相关视频',
    enableKey: SettingBoxKey.enableMinDurationForRcmd,
    onEnableChanged: (val) => RecommendFilter.enableMinDurationForRcmd = val,
  ),
  getVideoFilterSelectModel(
    title: '播放量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
    filterScope: '推荐、热门、分区、相关视频',
    enableKey: SettingBoxKey.enableMinPlayForRcmd,
    onEnableChanged: (val) => RecommendFilter.enableMinPlayForRcmd = val,
  ),
  SwitchModel(
    title: '已关注UP豁免推荐过滤',
    subtitle: '推荐中已关注用户发布的内容不会被过滤',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  SwitchModel(
    title: '过滤器也应用于详情页相关视频',
    subtitle: '其它（如热门视频、搜索等）均不受过滤器影响，无法豁免相关视频中的已关注UP',
    leading: const Icon(Icons.explore_outlined),
    setKey: SettingBoxKey.applyFilterToRelatedVideos,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.applyFilterToRelatedVideos = value,
  ),
  ...buildFishFilterSettings(),
  getBanWordModel(
    title: '评论区关键词过滤',
    key: SettingBoxKey.banWordForReply,
    banScope: '评论区',
    onChanged: (value) {
      ReplyGrpc.replyRegExp = value;
      ReplyGrpc.enableFilter =
          ReplyGrpc.enableBanWordForReply && value.pattern.isNotEmpty;
    },
    enableKey: SettingBoxKey.enableBanWordForReply,
    onEnableChanged: (val) {
      ReplyGrpc.enableBanWordForReply = val;
      ReplyGrpc.enableFilter = val && ReplyGrpc.replyRegExp.pattern.isNotEmpty;
    },
  ),
  PopupModel<CommentIpFilterMode>(
    title: '评论过滤-博主特定模式',
    leading: const Icon(Icons.tune_outlined),
    value: () => Pref.commentWordFilterMode,
    items: CommentIpFilterMode.values,
    onSelected: (value, setState) {
      GStorage.setting.put(SettingBoxKey.commentWordFilterMode, value.index);
      ReplyGrpc.commentWordFilterMode = value;
      setState();
    },
  ),
  NormalModel(
    title: '评论过滤-选择生效博主',
    leading: const Icon(Icons.people_outline),
    getSubtitle: () =>
        '从关注列表中勾选，当前已选 ${Pref.targetUpMidsForWordFilter.length} 位博主',
    onTap: (context, setState) {
      SelectTargetUpDialog.show(
        context,
        title: '评论过滤-选择生效博主',
        initialMids: Pref.targetUpMidsForWordFilter,
        onSaveMids: (mids) {
          Pref.targetUpMidsForWordFilter = mids;
          ReplyGrpc.targetUpMidsForWord = mids;
        },
      ).whenComplete(setState);
    },
  ),
  getBanWordModel(
    title: '评论区用户IP属地过滤',
    key: SettingBoxKey.banIpForReply,
    banScope: '评论区',
    onChanged: (value) {
      ReplyGrpc.replyIpRegExp = value;
      ReplyGrpc.enableIpFilter =
          ReplyGrpc.enableBanIpForReply && value.pattern.isNotEmpty;
    },
    enableKey: SettingBoxKey.enableBanIpForReply,
    onEnableChanged: (val) {
      ReplyGrpc.enableBanIpForReply = val;
      ReplyGrpc.enableIpFilter =
          val && ReplyGrpc.replyIpRegExp.pattern.isNotEmpty;
    },
  ),
  PopupModel<CommentIpFilterMode>(
    title: 'IP过滤-博主特定模式',
    leading: const Icon(Icons.tune_outlined),
    value: () => Pref.commentIpFilterMode,
    items: CommentIpFilterMode.values,
    onSelected: (value, setState) {
      GStorage.setting.put(SettingBoxKey.commentIpFilterMode, value.index);
      ReplyGrpc.commentIpFilterMode = value;
      setState();
    },
  ),
  NormalModel(
    title: 'IP过滤-选择生效博主',
    leading: const Icon(Icons.people_outline),
    getSubtitle: () =>
        '从关注列表中勾选，当前已选 ${Pref.targetUpMidsForIpFilter.length} 位博主',
    onTap: (context, setState) {
      SelectTargetUpDialog.show(
        context,
        title: 'IP过滤-选择生效博主',
        initialMids: Pref.targetUpMidsForIpFilter,
        onSaveMids: (mids) {
          Pref.targetUpMidsForIpFilter = mids;
          ReplyGrpc.targetUpMids = mids;
        },
      ).whenComplete(setState);
    },
  ),
];

Future<void> _showRcmdSourceDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<RcmdSource>(
    context: context,
    builder: (context) => SelectDialog<RcmdSource>(
      title: '首页推荐来源',
      value: Pref.rcmdSource,
      values: RcmdSource.values.map((e) => (e, e.label)).toList(),
      subtitleBuilder: (context, index, type) {
        if (type == .desktop) {
          return const Text(
            '沿用公开的网页推荐接口，按哔哩哔哩官方 Windows 客户端'
            '首页实际发送的参数组合请求，不涉及私有接口与设备指纹',
          );
        }
        return null;
      },
    ),
  );
  if (res != null) {
    _switchRcmdSource(res, setState);
  }
}

void _switchRcmdSource(RcmdSource value, VoidCallback setState) {
  // 同步旧键（旧版本只有 app / web 二选一），保证降级后语义一致
  GStorage.setting
      .put(SettingBoxKey.appRcmd, value == RcmdSource.app)
      .whenComplete(setState);
  GStorage.setting.put(SettingBoxKey.rcmdSource, value.index);
  try {
    Get.find<RcmdController>()
      ..rcmdSource = value
      ..lastRefreshAt = null
      // 用 onReload 而不是 onRefresh：切换来源后不应把旧来源的列表
      // 拼到新来源的数据前面（"保留上次内容"只在同一来源内生效）
      ..onReload();
  } catch (e) {
    if (kDebugMode) debugPrint('$e');
  }
  SmartDialog.showToast('已切换为${value.label}');
}
