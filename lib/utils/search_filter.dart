import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class SearchFilter {
  static RegExp searchRegExp = RegExp(
    Pref.banWordForSearch,
    caseSensitive: false,
  );
  static bool enableBanWordForSearch = Pref.enableBanWordForSearch;
  static bool enableFilter =
      enableBanWordForSearch && searchRegExp.pattern.isNotEmpty;

  static bool filterItem(SearchVideoItemModel item) {
    if (!enableFilter) return false;
    if (item.title != null &&
        item.title!.isNotEmpty &&
        searchRegExp.hasMatch(item.title!)) {
      return true;
    }
    if (item.tag != null &&
        item.tag!.isNotEmpty &&
        searchRegExp.hasMatch(item.tag!)) {
      return true;
    }
    return false;
  }

  static bool filterTitle(String? title) {
    if (title == null || title.isEmpty || !enableFilter) {
      return false;
    }
    return searchRegExp.hasMatch(title);
  }
}
