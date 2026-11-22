import 'package:PiliPlus/models/common/enum_with_label.dart';

enum FishFilterStrictness with EnumWithLabel {
  loose('宽松（75分，极低误杀）', 75),
  standard('标准（60分，推荐）', 60),
  strict('严格（45分，强力过滤）', 45),
  ;

  @override
  final String label;
  final int threshold;
  const FishFilterStrictness(this.label, this.threshold);
}
