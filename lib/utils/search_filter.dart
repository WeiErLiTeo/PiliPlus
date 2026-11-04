import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class SearchFilter {
  static RegExp searchRegExp = RegExp(
    Pref.banWordForSearch,
    caseSensitive: false,
  );
  static bool enableFilter = searchRegExp.pattern.isNotEmpty;

  static bool filterTitle(String? title) {
    if (title == null || title.isEmpty || !enableFilter) {
      return false;
    }
    return searchRegExp.hasMatch(title);
  }
}
