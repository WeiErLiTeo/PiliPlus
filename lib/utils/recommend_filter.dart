import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class RecommendFilter {
  static int minDurationForRcmd = Pref.minDurationForRcmd;
  static bool enableMinDurationForRcmd = Pref.enableMinDurationForRcmd;
  static int minPlayForRcmd = Pref.minPlayForRcmd;
  static bool enableMinPlayForRcmd = Pref.enableMinPlayForRcmd;
  static int minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  static bool enableMinLikeRatioForRecommend =
      Pref.enableMinLikeRatioForRecommend;
  static bool exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  static bool applyFilterToRelatedVideos = Pref.applyFilterToRelatedVideos;
  static bool enableBanWordForRecommend = Pref.enableBanWordForRecommend;
  static RegExp rcmdRegExp = RegExp(
    Pref.banWordForRecommend,
    caseSensitive: false,
  );
  static bool enableFilter =
      enableBanWordForRecommend && rcmdRegExp.pattern.isNotEmpty;

  // (web/app)rcmd
  static bool filterWithExempt(BaseVideoItemModel videoItem) {
    //由于相关视频中没有已关注标签，只能视为非关注视频
    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }
    return filterAll(videoItem);
  }

  /// hot/rank/[filterAll]
  static bool filterLikeRatio(int? like, int? view) {
    if (view != null) {
      if (enableMinPlayForRcmd && view > -1 && view < minPlayForRcmd) {
        return true;
      }
      if (enableMinLikeRatioForRecommend &&
          like != null &&
          like > -1 &&
          like * 100 < minLikeRatioForRecommend * view) {
        return true;
      }
    }
    return false;
  }

  /// hot/rank/[filterAll]
  static bool filterTitle(String title) {
    return (enableBanWordForRecommend &&
        enableFilter &&
        rcmdRegExp.hasMatch(title));
  }

  /// [filterAll]
  static bool filterDuration(int duration) {
    return enableMinDurationForRcmd &&
        duration > 0 &&
        duration < minDurationForRcmd;
  }

  /// related/[filterWithExempt]
  static bool filterAll(BaseVideoItemModel videoItem) {
    return filterDuration(videoItem.duration) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterTitle(videoItem.title);
  }
}
