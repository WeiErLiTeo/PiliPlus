import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class MemberArchiveFilter {
  static RegExp memberArchiveRegExp = RegExp(
    Pref.banWordForMemberArchive,
    caseSensitive: false,
  );
  static bool enableFilter = memberArchiveRegExp.pattern.isNotEmpty;

  static bool filterTitle(String? title) {
    if (title == null || title.isEmpty || !enableFilter) {
      return false;
    }
    return memberArchiveRegExp.hasMatch(title);
  }
}
