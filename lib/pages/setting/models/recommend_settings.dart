import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/reply/comment_ip_filter_mode.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/select_target_up_dialog.dart';
import 'package:PiliPlus/utils/member_archive_filter.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/search_filter.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide StatefulBuilder;

List<SettingsModel> get recommendSettings => [
  const SwitchModel(
    title: '首页使用app端推荐',
    subtitle: '若web端推荐不太符合预期，可尝试切换至app端推荐',
    leading: Icon(Icons.model_training_outlined),
    setKey: SettingBoxKey.appRcmd,
    defaultVal: true,
    needReboot: true,
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
  ),
  getBanWordModel(
    title: '标题关键词过滤',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter = value.pattern.isNotEmpty;
    },
    banScope: '推荐、热门、分区、相关视频',
  ),
  getBanWordModel(
    title: '搜索结果过滤',
    key: SettingBoxKey.banWordForSearch,
    onChanged: (value) {
      SearchFilter.searchRegExp = value;
      SearchFilter.enableFilter = value.pattern.isNotEmpty;
    },
    banScope: '搜索结果列表（标题与标签）',
  ),
  getBanWordModel(
    title: 'UP主主页视频过滤',
    key: SettingBoxKey.banWordForMemberArchive,
    onChanged: (value) {
      MemberArchiveFilter.memberArchiveRegExp = value;
      MemberArchiveFilter.enableFilter = value.pattern.isNotEmpty;
    },
    banScope: 'UP主个人主页视频投稿',
  ),
  getBanWordModel(
    title: '分区关键词过滤',
    key: SettingBoxKey.banWordForZone,
    onChanged: (value) {
      VideoHttp.zoneRegExp = value;
      VideoHttp.enableFilter = value.pattern.isNotEmpty;
    },
    banScope: 'App推荐、热门、分区',
  ),
  getVideoFilterSelectModel(
    title: '视频时长',
    suffix: 's',
    key: SettingBoxKey.minDurationForRcmd,
    values: [0, 30, 60, 90, 120],
    onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
    filterScope: '推荐、相关视频',
  ),
  getVideoFilterSelectModel(
    title: '播放量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
    filterScope: '推荐、热门、分区、相关视频',
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
  getBanWordModel(
    title: '评论区关键词过滤',
    key: SettingBoxKey.banWordForReply,
    banScope: '评论区',
    onChanged: (value) {
      ReplyGrpc.replyRegExp = value;
      ReplyGrpc.enableFilter = value.pattern.isNotEmpty;
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
    onTap: (context, setState) => SelectTargetUpDialog.show(
      context,
      title: '评论过滤-选择生效博主',
      initialMids: Pref.targetUpMidsForWordFilter,
      onSaveMids: (mids) {
        Pref.targetUpMidsForWordFilter = mids;
        ReplyGrpc.targetUpMidsForWord = mids;
      },
    ).whenComplete(setState),
  ),
  getBanWordModel(
    title: '评论区用户IP属地过滤',
    key: SettingBoxKey.banIpForReply,
    banScope: '评论区',
    onChanged: (value) {
      ReplyGrpc.replyIpRegExp = value;
      ReplyGrpc.enableIpFilter = value.pattern.isNotEmpty;
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
    onTap: (context, setState) => SelectTargetUpDialog.show(
      context,
      title: 'IP过滤-选择生效博主',
      initialMids: Pref.targetUpMidsForIpFilter,
      onSaveMids: (mids) {
        Pref.targetUpMidsForIpFilter = mids;
        ReplyGrpc.targetUpMids = mids;
      },
    ).whenComplete(setState),
  ),
];
