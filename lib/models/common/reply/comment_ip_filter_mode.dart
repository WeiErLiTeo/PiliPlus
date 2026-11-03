import 'package:PiliPlus/models/common/enum_with_label.dart';

enum CommentIpFilterMode with EnumWithLabel {
  targetOnly('模式 A：仅对我选中的博主生效'),
  exemptTarget('模式 B：全站过滤（对我选中的博主豁免）'),
  ;

  @override
  final String label;
  const CommentIpFilterMode(this.label);
}
