import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/utils/filter_lock_manager.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class NormalItem extends StatefulWidget {
  final String? title;
  final ValueGetter<String>? getTitle;
  final String? subtitle;
  final ValueGetter<String>? getSubtitle;
  final Widget? leading;
  final Widget Function(ThemeData theme)? getTrailing;
  final void Function(BuildContext context, VoidCallback setState)? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? titleStyle;
  final int? lockNodeId;

  const NormalItem({
    this.title,
    this.getTitle,
    this.subtitle,
    this.getSubtitle,
    this.leading,
    this.getTrailing,
    this.onTap,
    this.contentPadding,
    this.titleStyle,
    this.lockNodeId,
    super.key,
  }) : assert(title != null || getTitle != null);

  @override
  State<NormalItem> createState() => _NormalItemState();
}

class _NormalItemState extends State<NormalItem> {
  @override
  Widget build(BuildContext context) {
    late final theme = Theme.of(context);
    Widget? subtitle;
    if ((widget.subtitle ?? widget.getSubtitle?.call()) case final text?) {
      subtitle = Text(
        text,
        style: theme.textTheme.labelMedium!.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }
    Widget tile = ListTile(
      contentPadding: widget.contentPadding,
      onTap: widget.onTap == null
          ? null
          : () => widget.onTap!(context, refresh),
      title: Text(
        widget.title ?? widget.getTitle!(),
        style: widget.titleStyle ?? theme.textTheme.titleMedium!,
      ),
      subtitle: subtitle,
      leading: widget.leading,
      trailing: widget.getTrailing?.call(theme),
    );
    if (widget.lockNodeId != null) {
      final nodeId = widget.lockNodeId!;
      tile = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) =>
            FilterLockManager.onNodeHoldStart(nodeId, e.position),
        onPointerMove: (e) =>
            FilterLockManager.onNodeHoldMove(nodeId, e.position),
        onPointerUp: (_) => FilterLockManager.onNodeHoldEnd(nodeId),
        onPointerCancel: (_) => FilterLockManager.onNodeHoldCancel(nodeId),
        child: tile,
      );
    }
    return tile;
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
