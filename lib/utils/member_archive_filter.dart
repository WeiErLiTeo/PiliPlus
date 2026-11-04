import 'package:PiliPlus/models/common/reply/comment_ip_filter_mode.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class MemberArchiveFilter {
  static RegExp memberArchiveRegExp = RegExp(
    Pref.banWordForMemberArchive,
    caseSensitive: false,
  );
  static bool enableBanWordForMemberArchive =
      Pref.enableBanWordForMemberArchive;
  static bool enableFilter =
      enableBanWordForMemberArchive && memberArchiveRegExp.pattern.isNotEmpty;
  static CommentIpFilterMode memberArchiveFilterMode =
      Pref.memberArchiveFilterMode;
  static Set<int> targetUpMids = Pref.targetUpMidsForMemberArchiveFilter;

  static bool shouldFilterForUp(Object? upMidObj) {
    if (!enableBanWordForMemberArchive || !enableFilter) return false;
    int? upMid;
    if (upMidObj is int) {
      upMid = upMidObj;
    } else if (upMidObj != null) {
      upMid = int.tryParse(upMidObj.toString());
    }
    final isTarget = upMid != null && targetUpMids.contains(upMid);
    if (memberArchiveFilterMode == CommentIpFilterMode.targetOnly) {
      return isTarget;
    } else {
      return !isTarget;
    }
  }

  static bool filterTitle(String? title, {Object? upMid}) {
    if (title == null || title.isEmpty) {
      return false;
    }
    if (!shouldFilterForUp(upMid)) {
      return false;
    }
    return memberArchiveRegExp.hasMatch(title);
  }
}
